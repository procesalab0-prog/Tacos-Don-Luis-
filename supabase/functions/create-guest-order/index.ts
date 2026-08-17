import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

const reply = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: cors });

const hex = (bytes: ArrayBuffer) =>
  [...new Uint8Array(bytes)].map((b) => b.toString(16).padStart(2, "0")).join("");

async function trackingToken(requestId: string) {
  const secret = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const key = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]
  );
  return hex(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(requestId)));
}

async function sha256(value: string) {
  return hex(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)));
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "Método no permitido" });

  try {
    const body = await req.json();
    const requestId = String(body.requestId || "");
    const branchSlug = String(body.branchSlug || "punto-canada");
    const fulfillment = String(body.fulfillmentType || "");
    const paymentMethod = String(body.paymentMethod || "");
    const scheduledForRaw = body.scheduledFor ? String(body.scheduledFor) : null;
    const customer = body.customer || {};
    const items = Array.isArray(body.items) ? body.items : [];
    const comboIds = Array.isArray(body.comboIds) ? body.comboIds.map(String).slice(0, 20) : [];
    const requestedLoyaltyPoints = Math.max(0, Math.floor(Number(body.loyaltyPoints) || 0));

    if (!/^[0-9a-f-]{36}$/i.test(requestId)) return reply(400, { error: "Solicitud inválida" });
    if (!["pickup", "delivery"].includes(fulfillment)) return reply(400, { error: "Tipo de entrega inválido" });
    if (!["cash", "transfer", "card_present", "clip_simulated"].includes(paymentMethod)) return reply(400, { error: "Método de pago inválido" });
    if (!String(customer.name || "").trim() || !/\d{7,}/.test(String(customer.phone || "").replace(/\D/g, ""))) {
      return reply(400, { error: "Nombre y teléfono son obligatorios" });
    }
    if (!items.length || items.length > 50) return reply(400, { error: "El pedido no contiene productos válidos" });
    if (scheduledForRaw && (Number.isNaN(Date.parse(scheduledForRaw)) || Date.parse(scheduledForRaw) < Date.now() + 10 * 60000 || Date.parse(scheduledForRaw) > Date.now() + 7 * 86400000)) return reply(400, { error: "El horario programado no es válido" });
    if (fulfillment === "delivery" && scheduledForRaw) return reply(400, { error: "Por ahora los pedidos programados son sólo para recoger" });
    if (fulfillment === "delivery" && (!body.address?.street || !body.deliveryZoneId)) {
      return reply(400, { error: "Falta la dirección o zona de entrega" });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false } },
    );
    const secureTrackingToken = await trackingToken(requestId);
    const trackingTokenHash = await sha256(secureTrackingToken);

    // Guests remain supported. When a valid Supabase session is present, bind the
    // order to that verified user so it survives refreshes and other devices.
    let customerUserId: string | null = null;
    let customerId: string | null = null;
    const authorization = req.headers.get("authorization") || "";
    if (authorization.toLowerCase().startsWith("bearer ")) {
      const accessToken = authorization.slice(7).trim();
      const { data: authData } = await supabase.auth.getUser(accessToken);
      if (authData.user) {
        customerUserId = authData.user.id;
        const { data: customerRecord } = await supabase
          .from("customers")
          .select("id")
          .eq("user_id", authData.user.id)
          .maybeSingle();
        customerId = customerRecord?.id || null;
      }
    }
    if (requestedLoyaltyPoints > 0 && !customerId) {
      return reply(401, { error: "Inicia sesión para pagar con puntos" });
    }

    const { data: existing } = await supabase
      .from("orders")
      .select("id,folio,public_code,status,total,promised_at,loyalty_points_redeemed,loyalty_discount")
      .eq("client_request_id", requestId)
      .maybeSingle();
    if (existing) return reply(200, { order: existing, trackingToken: secureTrackingToken, duplicate: true });

    const { data: branch, error: branchError } = await supabase
      .from("branches")
      .select("id,name,business_settings(*)")
      .eq("slug", branchSlug)
      .eq("is_active", true)
      .single();
    if (branchError || !branch) return reply(404, { error: "Sucursal no disponible" });

    const settings = Array.isArray(branch.business_settings)
      ? branch.business_settings[0]
      : branch.business_settings;
    if (!settings?.is_open) return reply(409, { error: "La sucursal está cerrada" });
    const paymentMethods = settings?.payment_methods || {};
    if (paymentMethod !== "clip_simulated" && paymentMethods[paymentMethod] === false) {
      return reply(409, { error: "Ese método de pago no está disponible" });
    }
    // Saturated mode keeps ordering open but extends the promise shown to customers.
    if (paymentMethod === "clip_simulated" && !settings?.demo_mode) return reply(409, { error: "El pago en línea con Clip aún no está habilitado" });
    if (fulfillment === "pickup" && !settings?.pickup_enabled) return reply(409, { error: "Los pedidos para recoger están pausados" });
    if (fulfillment === "delivery" && !settings?.delivery_enabled) return reply(409, { error: "Los envíos están pausados" });

    const normalized = items.map((item: any) => ({
      productId: String(item.productId || ""),
      quantity: Math.max(1, Math.min(30, Number(item.quantity) || 1)),
      notes: String(item.notes || "").slice(0, 300),
      modifierOptionIds: Array.isArray(item.modifierOptionIds) ? item.modifierOptionIds.map(String) : [],
    }));
    const productIds = [...new Set(normalized.map((x: any) => x.productId))];
    const { data: products, error: productError } = await supabase
      .from("products")
      .select("id,name,price,is_active,is_available")
      .eq("branch_id", branch.id)
      .in("id", productIds);
    if (productError || !products || products.length !== productIds.length) {
      return reply(400, { error: "Uno o más productos ya no están disponibles" });
    }
    const productMap = new Map(products.map((p: any) => [p.id, p]));
    if (products.some((p: any) => !p.is_active || !p.is_available)) {
      return reply(409, { error: "Uno o más productos están agotados" });
    }

    let comboDiscount = 0;
    if (comboIds.length) {
      const uniqueComboIds = [...new Set(comboIds)];
      const { data: combos, error: comboError } = await supabase.from("combos").select("id,name,price,components,is_active,starts_at,ends_at").eq("branch_id", branch.id).in("id", uniqueComboIds);
      if (comboError || !combos || combos.length !== uniqueComboIds.length) return reply(400, { error: "Uno de los combos ya no está disponible" });
      for (const comboId of comboIds) {
        const combo: any = combos.find((c: any) => c.id === comboId);
        const comboCount = comboIds.filter((id: string) => id === comboId).length;
        const now = Date.now();
        if (!combo?.is_active || (combo.starts_at && Date.parse(combo.starts_at) > now) || (combo.ends_at && Date.parse(combo.ends_at) < now)) return reply(409, { error: "Uno de los combos ya no está vigente" });
        const components = Array.isArray(combo.components) ? combo.components : [];
        let regular = 0;
        for (const part of components) {
          const pid = String(part.product_id || part.productId || "");
          const qty = Math.max(1, Number(part.quantity) || 1);
          const product: any = productMap.get(pid);
          const orderedQty = normalized.filter((x: any) => x.productId === pid && x.notes.includes("Combo: " + combo.name)).reduce((s: number, x: any) => s + x.quantity, 0);
          if (!product || orderedQty < qty * comboCount) return reply(400, { error: "El contenido del combo no coincide" });
          regular += Number(product.price) * qty;
        }
        comboDiscount += Math.max(0, regular - Number(combo.price));
      }
    }

    const optionIds = [...new Set(normalized.flatMap((x: any) => x.modifierOptionIds))];
    let options: any[] = [];
    if (optionIds.length) {
      const { data, error } = await supabase
        .from("modifier_options")
        .select("id,name,price_delta,is_available")
        .in("id", optionIds);
      if (error || !data || data.length !== optionIds.length || data.some((o: any) => !o.is_available)) {
        return reply(400, { error: "Una modificación ya no está disponible" });
      }
      options = data;
    }
    const optionMap = new Map(options.map((o: any) => [o.id, o]));

    let deliveryFee = 0;
    let zone = null;
    if (fulfillment === "delivery") {
      const { data, error } = await supabase
        .from("delivery_zones")
        .select("id,fee,minimum_order,is_active")
        .eq("id", body.deliveryZoneId)
        .eq("branch_id", branch.id)
        .single();
      if (error || !data?.is_active) return reply(400, { error: "Zona de entrega inválida" });
      zone = data;
      deliveryFee = Number(data.fee);
    }

    const pricedItems = normalized.map((line: any) => {
      const product: any = productMap.get(line.productId);
      const selected = line.modifierOptionIds.map((id: string) => optionMap.get(id)).filter(Boolean);
      const unitPrice = Number(product.price) + selected.reduce((sum: number, o: any) => sum + Number(o.price_delta), 0);
      return { ...line, product, selected, unitPrice, lineTotal: unitPrice * line.quantity };
    });
    const subtotal = pricedItems.reduce((sum: number, line: any) => sum + line.lineTotal, 0);
    const discountedSubtotal = Math.max(0, subtotal - comboDiscount);
    if (fulfillment === "delivery" && discountedSubtotal < Number(zone.minimum_order || settings.minimum_delivery_amount || 0)) {
      return reply(409, { error: "El pedido no alcanza el mínimo para envío" });
    }
    const total = discountedSubtotal + deliveryFee;
    const baseEta = fulfillment === "delivery" ? settings.delivery_eta_minutes : settings.pickup_eta_minutes;
    const eta = Number(baseEta || 20) + (settings?.is_saturated ? 20 : 0);
    const scheduledFor = scheduledForRaw ? new Date(scheduledForRaw).toISOString() : null;
    const promisedAt = scheduledFor || new Date(Date.now() + eta * 60000).toISOString();

    const { data: createdOrder, error: orderError } = await supabase
      .from("orders")
      .insert({
        client_request_id: requestId,
        tracking_token_hash: trackingTokenHash,
        branch_id: branch.id,
        customer_user_id: customerUserId,
        customer_id: customerId,
        is_demo: Boolean(settings?.demo_mode),
        guest_name: String(customer.name).trim().slice(0, 120),
        guest_phone: String(customer.phone).trim().slice(0, 30),
        channel: "web",
        fulfillment_type: fulfillment,
        status: "pending_acceptance",
        payment_method: paymentMethod,
        payment_status: paymentMethod === "clip_simulated" ? "paid" : paymentMethod === "transfer" ? "verification_pending" : "pending",
        promised_at: promisedAt,
        scheduled_for: scheduledFor,
        delivery_address: fulfillment === "delivery" ? {
          street: String(body.address.street || "").slice(0, 160),
          exterior_number: String(body.address.exteriorNumber || "").slice(0, 30),
          neighborhood: String(body.address.neighborhood || "").slice(0, 120),
          references: String(body.address.references || "").slice(0, 300),
          latitude: body.address.latitude || null,
          longitude: body.address.longitude || null,
        } : null,
        delivery_zone_id: zone?.id || null,
        customer_notes: String(paymentMethod === "clip_simulated" ? "PAGO CLIP SIMULADO · DEMO · " + (body.customerNotes || "") : (body.customerNotes || "")).slice(0, 300),
        subtotal,
        discount_total: comboDiscount,
        delivery_fee: deliveryFee,
        total,
      })
      .select("id,folio,public_code,status,total,promised_at,loyalty_points_redeemed,loyalty_discount")
      .single();

    if (orderError || !createdOrder) {
      if (orderError?.code === "23505") {
        const { data: duplicate } = await supabase.from("orders")
          .select("id,folio,public_code,status,total,promised_at,loyalty_points_redeemed,loyalty_discount")
          .eq("client_request_id", requestId).single();
        if (duplicate) return reply(200, { order: duplicate, trackingToken: secureTrackingToken, duplicate: true });
      }
      throw orderError || new Error("No fue posible crear el pedido");
    }
    let order = createdOrder;

    const orderItems = pricedItems.map((line: any) => ({
      order_id: order.id,
      product_id: line.product.id,
      product_name: line.product.name,
      unit_price: line.unitPrice,
      quantity: line.quantity,
      notes: line.notes || null,
      line_total: line.lineTotal,
    }));
    const { data: insertedItems, error: itemsError } = await supabase
      .from("order_items").insert(orderItems).select("id,product_id");
    if (itemsError || !insertedItems) {
      await supabase.from("orders").delete().eq("id", order.id);
      throw itemsError || new Error("No fue posible guardar los productos");
    }

    const modifierRows: any[] = [];
    insertedItems.forEach((saved: any) => {
      const source = pricedItems.find((line: any) => line.product.id === saved.product_id);
      source?.selected.forEach((option: any) => modifierRows.push({
        order_item_id: saved.id,
        modifier_option_id: option.id,
        option_name: option.name,
        price_delta: option.price_delta,
      }));
    });
    if (modifierRows.length) await supabase.from("order_item_modifiers").insert(modifierRows);

    await supabase.from("order_status_history").insert({
      order_id: order.id,
      from_status: null,
      to_status: "pending_acceptance",
      note: "Pedido recibido desde la web",
    });

    if (requestedLoyaltyPoints > 0 && customerId) {
      const { data: pointsResult, error: pointsError } = await supabase.rpc(
        "apply_loyalty_points_to_order",
        { p_order_id: order.id, p_customer_id: customerId, p_requested_points: requestedLoyaltyPoints },
      );
      if (pointsError) {
        await supabase.from("orders").delete().eq("id", order.id);
        return reply(409, { error: pointsError.message || "No fue posible aplicar los puntos" });
      }
      order = { ...order, total: Number(pointsResult.total), loyalty_points_redeemed: Number(pointsResult.points_used), loyalty_discount: Number(pointsResult.discount) };
    }

    return reply(201, { order, trackingToken: secureTrackingToken });
  } catch (error) {
    console.error(error);
    return reply(500, { error: "No pudimos registrar el pedido. Intenta nuevamente." });
  }
});

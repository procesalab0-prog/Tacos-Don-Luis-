import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};
const reply = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: cors });
const hex = (bytes: ArrayBuffer) => [...new Uint8Array(bytes)].map((b) => b.toString(16).padStart(2, "0")).join("");
const sha256 = async (value: string) => hex(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)));
const orderSelect = "id,folio,public_code,status,fulfillment_type,payment_status,subtotal,delivery_fee,total,promised_at,created_at,order_items(product_name,quantity,line_total,notes),order_status_history(to_status,note,created_at),driver_assignments(status,picked_up_at,delivered_at,incident_note,driver_user_id)";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "Método no permitido" });
  try {
    const token = String((await req.json()).token || "").trim().toLowerCase();
    if (!/^[a-f0-9]{64}$/.test(token)) return reply(400, { error: "Enlace de seguimiento inválido" });
    const tokenHash = await sha256(token);
    const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

    let { data: order } = await db.from("orders").select(orderSelect).eq("tracking_token_hash", tokenHash).maybeSingle();
    if (!order) {
      const { data: link } = await db.from("order_tracking_links").select("order_id").eq("token_hash", tokenHash).is("revoked_at", null).maybeSingle();
      if (link) ({ data: order } = await db.from("orders").select(orderSelect).eq("id", link.order_id).maybeSingle());
    }
    if (!order) return reply(404, { error: "Pedido no encontrado o enlace vencido" });

    // Datos del repartidor asignado, para que el cliente sepa quién le llega.
    // Se envían solo el nombre, el vehículo y las placas: nada de contacto
    // personal ni de su ubicación.
    const asignacion = (order.driver_assignments || []).find((a: any) => a.driver_user_id);
    if (asignacion?.driver_user_id) {
      const [{ data: perfil }, { data: estado }] = await Promise.all([
        db.from("profiles").select("full_name").eq("id", asignacion.driver_user_id).maybeSingle(),
        db.from("driver_status").select("vehicle_type,vehicle_plate,vehicle_color").eq("user_id", asignacion.driver_user_id).maybeSingle(),
      ]);
      if (perfil || estado) {
        (order as any).repartidor = {
          nombre: perfil?.full_name ?? null,
          vehiculo: estado?.vehicle_type ?? null,
          placas: estado?.vehicle_plate ?? null,
          color: estado?.vehicle_color ?? null,
        };
      }
    }
    return reply(200, { order });
  } catch (error) {
    console.error(error);
    return reply(500, { error: "No pudimos consultar el pedido" });
  }
});

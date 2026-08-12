import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.57.4";

// Recibe la calificación del cliente usando el mismo token de seguimiento que
// ya identifica su pedido, para que también los invitados puedan opinar sin
// tener cuenta. La reseña nace sin publicar: el negocio decide cuáles muestra.

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};
const reply = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: cors });
const hex = (bytes: ArrayBuffer) => [...new Uint8Array(bytes)].map((b) => b.toString(16).padStart(2, "0")).join("");
const sha256 = async (value: string) => hex(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)));

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "Método no permitido" });
  try {
    const body = await req.json();
    const token = String(body.token || "").trim().toLowerCase();
    const rating = Number(body.rating);
    const comment = String(body.comment || "").trim().slice(0, 600);
    const displayName = String(body.displayName || "").trim().slice(0, 60);

    if (!/^[a-f0-9]{64}$/.test(token)) return reply(400, { error: "Enlace de seguimiento inválido" });
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) return reply(400, { error: "La calificación debe ser de 1 a 5 estrellas" });
    if (rating < 3 && comment.length < 4) return reply(400, { error: "Cuéntanos qué pasó para poder mejorarlo" });

    const tokenHash = await sha256(token);
    const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

    let { data: order } = await db.from("orders").select("id,branch_id,status,customer_id").eq("tracking_token_hash", tokenHash).maybeSingle();
    if (!order) {
      const { data: link } = await db.from("order_tracking_links").select("order_id").eq("token_hash", tokenHash).is("revoked_at", null).maybeSingle();
      if (link) ({ data: order } = await db.from("orders").select("id,branch_id,status,customer_id").eq("id", link.order_id).maybeSingle());
    }
    if (!order) return reply(404, { error: "Pedido no encontrado o enlace vencido" });
    if (order.status !== "delivered") return reply(409, { error: "Podrás calificar cuando tu pedido esté entregado" });

    const { error } = await db.from("order_reviews").upsert({
      order_id: order.id,
      branch_id: order.branch_id,
      customer_id: order.customer_id ?? null,
      rating,
      comment: comment || null,
      display_name: displayName || null,
    }, { onConflict: "order_id" });

    if (error) {
      console.error(error);
      return reply(500, { error: "No pudimos guardar tu calificación" });
    }
    return reply(200, { ok: true });
  } catch (error) {
    console.error(error);
    return reply(500, { error: "No pudimos guardar tu calificación" });
  }
});

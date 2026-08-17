import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const allowedOrigins = new Set(["https://tacosdonluis.app", "https://www.tacosdonluis.app", "https://tacos-don-luis.vercel.app"]);
const corsFor = (req: Request) => ({
  "Access-Control-Allow-Origin": allowedOrigins.has(req.headers.get("origin") || "") ? req.headers.get("origin")! : "https://tacosdonluis.app",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
  "Vary": "Origin",
});
const hex = (bytes: ArrayBuffer | Uint8Array) => [...new Uint8Array(bytes)].map((b) => b.toString(16).padStart(2, "0")).join("");
const sha256 = async (value: string) => hex(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)));

Deno.serve(async (req: Request) => {
  const cors = corsFor(req);
  const reply = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: cors });
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "Método no permitido" });
  try {
    const authorization = req.headers.get("authorization") || "";
    const accessToken = authorization.toLowerCase().startsWith("bearer ") ? authorization.slice(7).trim() : "";
    if (!accessToken) return reply(401, { error: "Sesión requerida" });

    const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
    const { data: authData } = await db.auth.getUser(accessToken);
    if (!authData.user) return reply(401, { error: "Sesión inválida" });

    const orderId = String((await req.json()).order_id || "");
    if (!/^[0-9a-f-]{36}$/i.test(orderId)) return reply(400, { error: "Pedido inválido" });
    const { data: order } = await db.from("orders").select("id,branch_id").eq("id", orderId).maybeSingle();
    if (!order) return reply(404, { error: "Pedido no encontrado" });
    const { data: membership } = await db.from("branch_memberships").select("id,role").eq("branch_id", order.branch_id).eq("user_id", authData.user.id).eq("is_active", true).maybeSingle();
    if (!membership || !["owner", "admin", "cashier"].includes(membership.role)) return reply(403, { error: "No tienes permiso para confirmar pedidos" });

    const token = hex(crypto.getRandomValues(new Uint8Array(32)));
    const { error } = await db.from("order_tracking_links").insert({ order_id: order.id, token_hash: await sha256(token), created_by: authData.user.id });
    if (error) throw error;
    return reply(201, { token });
  } catch (error) {
    console.error(error);
    return reply(500, { error: "No pudimos crear el enlace de seguimiento" });
  }
});

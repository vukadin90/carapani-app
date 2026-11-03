import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405);
  try {
    const url = Deno.env.get("SUPABASE_URL");
    const anon = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("MY_SERVICE_ROLE_KEY");
    const publicKey = Deno.env.get("VAPID_PUBLIC_KEY");
    const privateKey = Deno.env.get("VAPID_PRIVATE_KEY");
    if (!url || !anon || !serviceKey || !publicKey || !privateKey) {
      return reply({ error: "Nedostaju Edge Function Secrets za push." }, 500);
    }
    const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
    if (!token) return reply({ error: "Unauthorized" }, 401);
    const userClient = createClient(url, anon, { global: { headers: { Authorization: `Bearer ${token}` } } });
    const { data: { user }, error: authError } = await userClient.auth.getUser(token);
    if (authError || !user) return reply({ error: "Unauthorized" }, 401);

    let payload: { ride_id?: string };
    try { payload = await req.json(); } catch { return reply({ error: "Neispravan JSON zahtev." }, 400); }
    const rideId = payload.ride_id || "";
    if (typeof rideId !== "string" || !rideId.trim() || rideId.length > 128) {
      return reply({ error: "Nedostaje ili nije ispravan ID moto vožnje." }, 400);
    }

    const admin = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
    const { data: sender, error: senderError } = await admin.from("profiles").select("id,approved").eq("id", user.id).maybeSingle();
    if (senderError) throw senderError;
    if (!sender || sender.approved !== true) return reply({ error: "Samo odobren član može poslati zahtev." }, 403);

    const { data: ride, error: rideError } = await admin.from("rides").select("id,user_id,title,is_approved").eq("id", rideId).maybeSingle();
    if (rideError) throw rideError;
    if (!ride || ride.user_id !== user.id || ride.is_approved !== false) return reply({ error: "Moto vožnja nije pronađena ili ne čeka odobrenje." }, 403);

    const { data: admins, error: adminsError } = await admin.from("profiles").select("id").eq("approved", true).eq("is_admin", true);
    if (adminsError) throw adminsError;
    const adminIds = (admins || []).map((x: { id: string }) => x.id);
    if (!adminIds.length) return reply({ sent: 0, failed: 0, reason: "Nema odobrenih administratora." });

    const { data: subscriptions, error: subsError } = await admin.from("push_subscriptions").select("id,user_id,endpoint,p256dh,auth").in("user_id", adminIds);
    if (subsError) throw subsError;
    if (!subscriptions?.length) return reply({ sent: 0, failed: 0, reason: "Administrator nema uključena push obaveštenja." });

    webpush.setVapidDetails("mailto:carapani-klub@example.com", publicKey, privateKey);
    const message = JSON.stringify({
      title: "Nova moto vožnja na odobrenju",
      body: `${String(ride.title || "Moto vožnja").slice(0, 120)} čeka tvoje odobrenje.`,
      tag: `carapani-pending-ride-${ride.id}`,
      url: "https://vukadin90.github.io/carapani-app/?open=admin",
    });
    let sent = 0, failed = 0;
    for (const sub of subscriptions) {
      try {
        await webpush.sendNotification({ endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } }, message);
        sent++;
      } catch (error) {
        failed++;
        const status = (error as { statusCode?: number })?.statusCode;
        if (status === 404 || status === 410) await admin.from("push_subscriptions").delete().eq("id", sub.id);
        console.error("Pending ride push failed:", status, error);
      }
    }
    return reply({ sent, failed, subscriptions: subscriptions.length });
  } catch (error) {
    console.error("notify-pending-ride error:", error);
    return reply({ error: error instanceof Error ? error.message : "Internal error" }, 500);
  }
});

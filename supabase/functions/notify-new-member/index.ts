import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405);

  try {
    const url = Deno.env.get("SUPABASE_URL");
    const anon = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceKey =
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
      Deno.env.get("MY_SERVICE_ROLE_KEY");
    const publicKey = Deno.env.get("VAPID_PUBLIC_KEY");
    const privateKey = Deno.env.get("VAPID_PRIVATE_KEY");

    if (!url || !anon || !serviceKey || !publicKey || !privateKey) {
      return reply({ error: "Nedostaju Edge Function Secrets za push." }, 500);
    }

    // This endpoint is called immediately after sign-up, before email confirmation
    // may have created an authenticated browser session. Only the public project
    // key is accepted here; the submitted user ID is independently validated below.
    if (req.headers.get("apikey") !== anon) {
      return reply({ error: "Nevažeći API ključ." }, 401);
    }

    let payload: { user_id?: string };
    try {
      payload = await req.json();
    } catch {
      return reply({ error: "Neispravan JSON zahtev." }, 400);
    }

    const userId = payload.user_id ?? "";
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(userId)) {
      return reply({ error: "Neispravan ID novog člana." }, 400);
    }

    const admin = createClient(url, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: member, error: memberError } = await admin
      .from("profiles")
      .select("id, full_name, approved, created_at")
      .eq("id", userId)
      .maybeSingle();

    if (memberError) throw memberError;
    if (!member || member.approved === true || !member.created_at) {
      return reply({ error: "Nije pronađen novi član koji čeka odobrenje." }, 404);
    }

    const ageMs = Date.now() - new Date(member.created_at).getTime();
    if (!Number.isFinite(ageMs) || ageMs < -60_000 || ageMs > 15 * 60_000) {
      return reply({ error: "Zahtev nije vezan za nedavnu registraciju." }, 403);
    }

    const { data: admins, error: adminsError } = await admin
      .from("profiles")
      .select("id")
      .eq("approved", true)
      .eq("is_admin", true);

    if (adminsError) throw adminsError;
    const adminIds = (admins ?? []).map((row: { id: string }) => row.id);
    if (!adminIds.length) return reply({ sent: 0, failed: 0, reason: "Nema odobrenih administratora." });

    const { data: subscriptions, error: subscriptionsError } = await admin
      .from("push_subscriptions")
      .select("id, user_id, endpoint, p256dh, auth")
      .in("user_id", adminIds);

    if (subscriptionsError) throw subscriptionsError;
    if (!subscriptions?.length) {
      return reply({ sent: 0, failed: 0, reason: "Administrator još nema uključena push obaveštenja." });
    }

    // Unique user_id prevents duplicate notifications if the browser retries the request.
    const { error: logError } = await admin
      .from("registration_push_log")
      .insert({ user_id: userId });

    if (logError?.code === "23505") {
      return reply({ sent: 0, failed: 0, duplicate: true });
    }
    if (logError) throw logError;

    webpush.setVapidDetails("https://vukadin90.github.io/carapani-app/", publicKey, privateKey);

    const name = String(member.full_name || "Novi član").slice(0, 100);
    const message = JSON.stringify({
      title: "Nova prijava za članstvo",
      body: `${name} čeka tvoje odobrenje.`,
      tag: `carapani-new-member-${userId}`,
      url: "https://vukadin90.github.io/carapani-app/?open=admin",
    });

    let sent = 0;
    let failed = 0;
    for (const sub of subscriptions) {
      try {
        await webpush.sendNotification(
          { endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } },
          message,
        );
        sent++;
      } catch (error) {
        failed++;
        const status = (error as { statusCode?: number })?.statusCode;
        if (status === 404 || status === 410) {
          await admin.from("push_subscriptions").delete().eq("id", sub.id);
        }
        console.error("Registration push failed:", status, error);
      }
    }

    if (sent === 0) {
      await admin.from("registration_push_log").delete().eq("user_id", userId);
    }

    return reply({ sent, failed, subscriptions: subscriptions.length });
  } catch (error) {
    console.error("notify-new-member error:", error);
    return reply({ error: error instanceof Error ? error.message : "Internal error" }, 500);
  }
});

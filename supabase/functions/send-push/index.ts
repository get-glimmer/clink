import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

// Build a signed JWT for APNs using the ES256 algorithm
async function buildApnsJwt(
  privateKeyPem: string,
  keyId: string,
  teamId: string
): Promise<string> {
  // Strip PEM headers and decode base64
  const pemBody = privateKeyPem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const keyData = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  // JWT header + payload
  const header = { alg: "ES256", kid: keyId };
  const payload = {
    iss: teamId,
    iat: Math.floor(Date.now() / 1000),
  };

  const encode = (obj: unknown) =>
    btoa(JSON.stringify(obj))
      .replace(/=/g, "")
      .replace(/\+/g, "-")
      .replace(/\//g, "_");

  const headerB64 = encode(header);
  const payloadB64 = encode(payload);
  const signingInput = `${headerB64}.${payloadB64}`;

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput)
  );

  // Convert DER signature to raw r||s format expected by JWT
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

  return `${signingInput}.${sigB64}`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { user_id, title, body } = await req.json();

    if (!user_id || !title || !body) {
      return new Response(
        JSON.stringify({ error: "user_id, title, and body are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Look up device tokens for the target user
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const { data: tokens, error: tokensError } = await supabase
      .from("device_tokens")
      .select("token")
      .eq("user_id", user_id)
      .eq("platform", "ios");

    if (tokensError) throw tokensError;
    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ message: "No device tokens found for user" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Build APNs JWT
    const apnsKey = Deno.env.get("APNS_KEY") ?? "";
    const keyId = Deno.env.get("APNS_KEY_ID") ?? "";
    const teamId = Deno.env.get("APNS_TEAM_ID") ?? "";
    const bundleId = "Kristie123.mobile";

    const jwt = await buildApnsJwt(apnsKey, keyId, teamId);

    // Send to each device token
    const results = await Promise.allSettled(
      tokens.map(async ({ token }: { token: string }) => {
        const apnsPayload = {
          aps: {
            alert: { title, body },
            sound: "default",
            badge: 1,
          },
        };

        const res = await fetch(
          `https://api.development.push.apple.com/3/device/${token}`,
          {
            method: "POST",
            headers: {
              authorization: `bearer ${jwt}`,
              "apns-topic": bundleId,
              "apns-push-type": "alert",
              "apns-priority": "10",
              "content-type": "application/json",
            },
            body: JSON.stringify(apnsPayload),
          }
        );

        if (!res.ok) {
          const errBody = await res.text();
          console.error(`APNs error for token ${token}: ${res.status} ${errBody}`);
          throw new Error(`APNs ${res.status}: ${errBody}`);
        }

        return { token, status: "sent" };
      })
    );

    return new Response(JSON.stringify({ results }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("send-push error:", error);
    return new Response(
      JSON.stringify({ error: error.message ?? "Unknown error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

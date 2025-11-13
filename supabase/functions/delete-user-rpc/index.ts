import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: req.headers.get("Authorization")! },
        },
      }
    );

    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();
    if (userError) throw userError;
    if (!user) throw new Error("User not found for deletion.");

    const adminClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const { error: deleteError } = await adminClient.auth.admin.deleteUser(
      user.id
    );
    if (deleteError) throw deleteError;

    return new Response(
      JSON.stringify({ message: "User deleted successfully" }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    // ✅ THIS IS THE FINAL, IMPROVED CATCH BLOCK
    console.error("Raw error object:", error); // Log the full error to the server

    // Supabase often nests the real database error. Let's find it.
    const dbError = error.dbError || error;
    const errorMessage = dbError.message || "An unknown error occurred.";
    const errorDetails = dbError.details || "No additional details.";
    const errorCode = dbError.code || "N/A";

    const errorPayload = {
      message: errorMessage,
      details: errorDetails,
      code: errorCode,
    };

    return new Response(JSON.stringify(errorPayload), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});

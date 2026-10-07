import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const authorization = request.headers.get("Authorization");
  const bearerToken = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!bearerToken || !supabaseUrl || !anonKey || !serviceRoleKey) {
    return jsonResponse({ error: "Authentication service is not configured." }, 500);
  }

  const authClient = createClient(supabaseUrl, anonKey);
  const { data: authData, error: authError } =
    await authClient.auth.getUser(bearerToken);
  if (authError || !authData.user) {
    return jsonResponse({ error: "Sign in as an administrator to continue." }, 401);
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: adminProfile, error: adminProfileError } = await adminClient
    .from("users")
    .select("role, account_status")
    .eq("auth_user_id", authData.user.id)
    .maybeSingle();
  if (
    adminProfileError ||
    adminProfile?.role !== "admin" ||
    adminProfile.account_status !== "active"
  ) {
    return jsonResponse({ error: "Active administrator access is required." }, 403);
  }

  const { data: adminRoleProfile, error: adminRoleProfileError } =
    await adminClient
      .from("admins")
      .select("id")
      .eq("user_id", authData.user.id)
      .maybeSingle();
  if (adminRoleProfileError || !adminRoleProfile) {
    return jsonResponse({ error: "The administrator profile is missing." }, 403);
  }

  let input: Record<string, unknown>;
  try {
    input = await request.json();
  } catch {
    return jsonResponse({ error: "Invalid request body." }, 400);
  }

  const email =
    typeof input.email === "string" ? input.email.trim().toLowerCase() : "";
  const name = typeof input.name === "string" ? input.name.trim() : "";
  const password = typeof input.password === "string" ? input.password : "";
  const role = typeof input.role === "string" ? input.role : "";
  if (
    !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) ||
    name.length < 1 ||
    name.length > 120 ||
    password.length < 6 ||
    !["admin", "job_seeker", "employer"].includes(role)
  ) {
    return jsonResponse(
      { error: "Provide a valid email, name, password, and account role." },
      400,
    );
  }

  const { data: created, error: createError } =
    await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { name, role },
      ...(role === "admin" ? { app_metadata: { role: "admin" } } : {}),
    });
  if (createError || !created.user) {
    console.error("Admin account creation failed:", createError);
    return jsonResponse(
      { error: createError?.message ?? "Unable to create the account." },
      400,
    );
  }

  return jsonResponse({ user_id: created.user.id });
});

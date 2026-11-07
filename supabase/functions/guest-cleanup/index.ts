// Remove imediatamente a própria conta Supabase de um usuário anônimo.
// Nunca aceita user_id no corpo: a identidade vem exclusivamente do JWT validado.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json',
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  const authHeader = req.headers.get('Authorization') || '';
  const token = authHeader.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) return json({ error: 'Unauthorized' }, 401);

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const publishableMap = Deno.env.get('SUPABASE_PUBLISHABLE_KEYS');
  const secretMap = Deno.env.get('SUPABASE_SECRET_KEYS');
  const anonKey = publishableMap
    ? JSON.parse(publishableMap).default
    : Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = secretMap
    ? JSON.parse(secretMap).default
    : Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return json({ error: 'Server configuration missing' }, 500);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser(token);
  if (userError || !userData.user) return json({ error: 'Invalid session' }, 401);
  if (userData.user.is_anonymous !== true) {
    return json({ error: 'Only anonymous sessions can be deleted here' }, 403);
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { error: deleteError } = await adminClient.auth.admin.deleteUser(userData.user.id);
  if (deleteError) {
    console.error('Guest deletion failed', deleteError.message);
    return json({ error: 'Could not delete temporary account' }, 500);
  }

  return json({ deleted: true });
});

function json(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), { status, headers: corsHeaders });
}

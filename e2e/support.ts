// Test-only helpers. The service_role key lives here and in CI env, never in web/src.
const url = process.env.VITE_SUPABASE_URL ?? '';
const anonKey = process.env.VITE_SUPABASE_ANON_KEY ?? '';
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY ?? '';

export interface TestUser {
  id: string;
  email: string;
  password: string;
}

async function call(path: string, init: RequestInit & { headers: Record<string, string> }) {
  const res = await fetch(`${url}${path}`, init);
  const text = await res.text();
  let body: unknown;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = text;
  }
  return { status: res.status, body: body as Record<string, unknown> | null };
}

const admin = () => ({
  apikey: serviceKey,
  Authorization: `Bearer ${serviceKey}`,
  'Content-Type': 'application/json',
});

/** Creates an auth user with a profile and one role, through the service role. */
export async function createUser(role: string): Promise<TestUser> {
  const email = `${role}-${crypto.randomUUID()}@e2e.test`;
  const password = `pw-${crypto.randomUUID()}`;
  const created = await call('/auth/v1/admin/users', {
    method: 'POST',
    headers: admin(),
    body: JSON.stringify({ email, password, email_confirm: true }),
  });
  if (created.status >= 300) throw new Error(`create user failed: ${JSON.stringify(created)}`);
  const id = String(created.body?.id);
  for (const [table, row] of [
    ['profiles', { id, full_name: role, active: true }],
    ['user_roles', { user_id: id, role }],
  ] as const) {
    const r = await call(`/rest/v1/${table}`, {
      method: 'POST',
      headers: { ...admin(), Prefer: 'return=minimal' },
      body: JSON.stringify(row),
    });
    if (r.status >= 300) throw new Error(`insert into ${table} failed: ${JSON.stringify(r)}`);
  }
  return { id, email, password };
}

/** Password sign-in; returns the access token the browser would hold. */
export async function signIn(user: TestUser): Promise<string> {
  const r = await call('/auth/v1/token?grant_type=password', {
    method: 'POST',
    headers: { apikey: anonKey, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: user.email, password: user.password }),
  });
  if (r.status !== 200) throw new Error(`sign in failed: ${JSON.stringify(r)}`);
  return String(r.body?.access_token);
}

const asUser = (token: string) => ({
  apikey: anonKey,
  Authorization: `Bearer ${token}`,
  'Content-Type': 'application/json',
});

export const rpc = (token: string, fn: string, args: Record<string, unknown>) =>
  call(`/rest/v1/rpc/${fn}`, { method: 'POST', headers: asUser(token), body: JSON.stringify(args) });

export const patch = (token: string, path: string, body: Record<string, unknown>) =>
  call(`/rest/v1/${path}`, { method: 'PATCH', headers: asUser(token), body: JSON.stringify(body) });

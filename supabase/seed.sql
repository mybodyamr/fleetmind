-- DEV AND CI ONLY. Applied by `supabase start` / `supabase db reset`, never by
-- `supabase db push`, so none of this reaches production.
-- Holds the pgTAP test helpers (schema "tests") and, later, development data.

create schema if not exists tests;

-- Creates an auth user with a profile and, optionally, one role.
-- p_role = null creates a user with no role at all.
create or replace function tests.create_user(p_role text default null, p_active boolean default true)
returns uuid
language plpgsql
as $$
declare
  v_id uuid := gen_random_uuid();
begin
  insert into auth.users (id, email, aud, role)
  values (v_id, v_id || '@test.local', 'authenticated', 'authenticated');
  insert into public.profiles (id, active) values (v_id, p_active);
  if p_role is not null then
    insert into public.user_roles (user_id, role) values (v_id, p_role);
  end if;
  return v_id;
end;
$$;

-- Makes the rest of the transaction run as this user (what the API does with a JWT).
create or replace function tests.as_user(p_user uuid)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

-- Makes the rest of the transaction run as the anonymous API role.
create or replace function tests.as_anon()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('role', 'anon', true);
end;
$$;

-- Back to the privileged test runner.
create or replace function tests.reset()
returns void
language plpgsql
as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
end;
$$;

grant usage on schema tests to anon, authenticated;
grant execute on all functions in schema tests to anon, authenticated;

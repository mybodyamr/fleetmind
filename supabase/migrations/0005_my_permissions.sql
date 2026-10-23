-- The caller's permission codes in one round trip (the UI uses it to decide what to show).
-- Same rules as has_permission(): anonymous callers and inactive accounts get nothing.
-- This only shapes the UI; every write is still checked by the database itself.
create or replace function public.my_permissions()
returns setof text
language sql
stable
security definer
set search_path = ''
as $$
  select distinct rp.permission
  from public.profiles p
  join public.user_roles ur on ur.user_id = p.id
  join public.role_permissions rp on rp.role = ur.role
  where p.id = auth.uid() and p.active;
$$;

revoke all on function public.my_permissions() from public, anon;
grant execute on function public.my_permissions() to authenticated, service_role;

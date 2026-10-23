-- Row level security for the identity tables, and the only write path to user_roles.

-- Table privileges: identity data is never anonymous; role assignments are written
-- only through assign_role/revoke_role; roles and permissions are read-only here.
revoke all on public.profiles, public.roles, public.permissions,
  public.role_permissions, public.user_roles from anon;
revoke insert, update, delete, truncate on public.user_roles from authenticated;
revoke insert, update, delete, truncate on public.roles, public.permissions from authenticated;

-- profiles: your own row, or everything for user managers.
create policy profiles_select on public.profiles for select to authenticated
  using (id = (select auth.uid()) or public.has_permission('users.manage'));
create policy profiles_insert on public.profiles for insert to authenticated
  with check (public.has_permission('users.manage'));
create policy profiles_update on public.profiles for update to authenticated
  using (public.has_permission('users.manage'))
  with check (public.has_permission('users.manage'));
create policy profiles_delete on public.profiles for delete to authenticated
  using (public.has_permission('users.manage'));

-- roles and permissions: reference data, readable by any signed-in user.
create policy roles_select on public.roles for select to authenticated using (true);
create policy permissions_select on public.permissions for select to authenticated using (true);

-- role_permissions: readable by any signed-in user, editable by user managers.
create policy role_permissions_select on public.role_permissions for select to authenticated using (true);
create policy role_permissions_insert on public.role_permissions for insert to authenticated
  with check (public.has_permission('users.manage'));
create policy role_permissions_update on public.role_permissions for update to authenticated
  using (public.has_permission('users.manage'))
  with check (public.has_permission('users.manage'));
create policy role_permissions_delete on public.role_permissions for delete to authenticated
  using (public.has_permission('users.manage'));

-- user_roles: your own roles, or everything for user managers. No write policies.
create policy user_roles_select on public.user_roles for select to authenticated
  using (user_id = (select auth.uid()) or public.has_permission('users.manage'));

-- Grants a role. Requires users.manage and a non-blank reason.
create or replace function public.assign_role(p_user uuid, p_role text, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_permission('users.manage') then
    raise exception 'permission denied: users.manage is required' using errcode = '42501';
  end if;
  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'a reason is required' using errcode = '22023';
  end if;
  insert into public.user_roles (user_id, role) values (p_user, p_role)
  on conflict do nothing;
end;
$$;

-- Removes a role. The last active system_admin cannot lose that role.
create or replace function public.revoke_role(p_user uuid, p_role text, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_permission('users.manage') then
    raise exception 'permission denied: users.manage is required' using errcode = '42501';
  end if;
  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'a reason is required' using errcode = '22023';
  end if;
  if p_role = 'system_admin'
     and exists (select 1 from public.user_roles where user_id = p_user and role = p_role)
     and not exists (
       select 1
       from public.user_roles ur
       join public.profiles p on p.id = ur.user_id
       where ur.role = 'system_admin' and p.active and ur.user_id <> p_user
     ) then
    raise exception 'cannot remove the last active system_admin' using errcode = '55000';
  end if;
  delete from public.user_roles where user_id = p_user and role = p_role;
end;
$$;

revoke all on function public.assign_role(uuid, text, text) from public;
revoke all on function public.revoke_role(uuid, text, text) from public;
grant execute on function public.assign_role(uuid, text, text) to authenticated, service_role;
grant execute on function public.revoke_role(uuid, text, text) to authenticated, service_role;

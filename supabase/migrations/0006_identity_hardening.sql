-- Hardening found in the Phase 0-1 review:
--  * profiles and role_permissions are written only through functions (or service_role);
--  * deactivating an account goes through set_profile_active(), which is audited and keeps
--    the last active system_admin in place;
--  * the last-admin checks and the interdependent GPS thresholds are serialized with
--    transaction-level advisory locks so two concurrent callers cannot both pass the check;
--  * anon and authenticated can execute only the functions that are part of the API.

-- 1. No direct writes. The write policies would be dead letters, so they go too.
revoke insert, update, delete, truncate on public.profiles, public.role_permissions from authenticated;
drop policy profiles_insert on public.profiles;
drop policy profiles_update on public.profiles;
drop policy profiles_delete on public.profiles;
drop policy role_permissions_insert on public.role_permissions;
drop policy role_permissions_update on public.role_permissions;
drop policy role_permissions_delete on public.role_permissions;

create trigger profiles_audit
  after insert or update or delete on public.profiles
  for each row execute function public.audit_row_change();

-- 2. Function privileges: nothing is callable by anon except has_permission.
revoke all on function public.assign_role(uuid, text, text) from anon;
revoke all on function public.revoke_role(uuid, text, text) from anon;
revoke all on function public.audit_log_block_change() from public, anon, authenticated;

-- 3. revoke_role takes the admin guard lock before checking.
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
  perform pg_advisory_xact_lock(hashtextextended('fleetmind.system_admin_guard', 0));
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
  perform set_config('fleetmind.reason', p_reason, true);
  delete from public.user_roles where user_id = p_user and role = p_role;
  perform set_config('fleetmind.reason', '', true);
end;
$$;

-- 4. Activate or deactivate an account. Requires users.manage and a reason.
create or replace function public.set_profile_active(p_user uuid, p_active boolean, p_reason text)
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
  perform pg_advisory_xact_lock(hashtextextended('fleetmind.system_admin_guard', 0));
  if not p_active
     and exists (select 1 from public.user_roles ur join public.profiles p on p.id = ur.user_id
                  where ur.user_id = p_user and ur.role = 'system_admin' and p.active)
     and not exists (
       select 1
       from public.user_roles ur
       join public.profiles p on p.id = ur.user_id
       where ur.role = 'system_admin' and p.active and ur.user_id <> p_user
     ) then
    raise exception 'cannot deactivate the last active system_admin' using errcode = '55000';
  end if;
  perform set_config('fleetmind.reason', p_reason, true);
  update public.profiles set active = p_active where id = p_user;
  perform set_config('fleetmind.reason', '', true);
end;
$$;

revoke all on function public.set_profile_active(uuid, boolean, text) from public, anon;
grant execute on function public.set_profile_active(uuid, boolean, text) to authenticated, service_role;

-- 5. set_setting serializes on the settings lock: stale < offline is checked against the
-- stored value of the other key, so two concurrent writers must not interleave.
create or replace function public.set_setting(p_key text, p_value jsonb, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.has_permission('settings.write') then
    raise exception 'permission denied: settings.write is required' using errcode = '42501';
  end if;
  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'a reason is required' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('fleetmind.settings', 0));
  if not public.validate_setting(p_key, p_value) then
    raise exception 'invalid value for setting %', p_key using errcode = '22023';
  end if;
  perform set_config('fleetmind.reason', p_reason, true);
  update public.settings
     set value = p_value, updated_by = auth.uid(), updated_at = now()
   where key = p_key;
  perform set_config('fleetmind.reason', '', true);
end;
$$;

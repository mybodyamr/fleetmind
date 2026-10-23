-- Append-only audit log. Rows are written by triggers and SECURITY DEFINER functions only.

create table public.audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid,                      -- no FK: history must outlive the user
  action text not null,
  entity text not null,
  entity_id uuid,
  old_data jsonb,
  new_data jsonb,
  reason text,
  at timestamptz not null default now()
);

create index audit_log_entity_idx on public.audit_log (entity, entity_id, at desc);
create index audit_log_at_idx on public.audit_log (at desc);

alter table public.audit_log enable row level security;

create policy audit_log_select on public.audit_log for select to authenticated
  using (public.has_permission('audit.read'));

revoke all on public.audit_log from public, anon, authenticated, service_role;
grant select on public.audit_log to authenticated, service_role;

-- No role, including the owner, may change or remove history.
create or replace function public.audit_log_block_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'audit_log is append-only' using errcode = '55000';
end;
$$;

create trigger audit_log_append_only
  before update or delete or truncate on public.audit_log
  for each statement execute function public.audit_log_block_change();

-- Attach to any table with: create trigger ... after insert or update or delete
--   for each row execute function public.audit_row_change('<column holding the entity uuid>');
-- The column argument defaults to 'id'; a missing or non-uuid column gives a null entity_id.
-- The reason comes from the transaction-local setting fleetmind.reason, set by the
-- function that performs the change (see assign_role).
create or replace function public.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_col text := coalesce(tg_argv[0], 'id');
  v_row jsonb := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  v_id uuid;
begin
  begin
    v_id := (v_row ->> v_col)::uuid;
  exception when others then
    v_id := null;
  end;
  insert into public.audit_log (actor_id, action, entity, entity_id, old_data, new_data, reason)
  values (
    auth.uid(), tg_op, tg_table_name, v_id,
    case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end,
    case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end,
    nullif(current_setting('fleetmind.reason', true), '')
  );
  return null;
end;
$$;

-- Explicit audit entry for events that are not row changes (task reassignment, overrides...).
-- Not callable through the API: only other SECURITY DEFINER functions and service_role use it.
create or replace function public.write_audit(
  p_action text, p_entity text, p_entity_id uuid, p_reason text, p_data jsonb)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.audit_log (actor_id, action, entity, entity_id, new_data, reason)
  values (auth.uid(), p_action, p_entity, p_entity_id, p_data, p_reason);
$$;

revoke all on function public.audit_row_change() from public, anon, authenticated;
revoke all on function public.write_audit(text, text, uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.write_audit(text, text, uuid, text, jsonb) to service_role;

create trigger user_roles_audit
  after insert or update or delete on public.user_roles
  for each row execute function public.audit_row_change('user_id');

create trigger role_permissions_audit
  after insert or update or delete on public.role_permissions
  for each row execute function public.audit_row_change();

-- assign_role/revoke_role now pass their reason to the audit trigger, then clear it so it
-- cannot leak onto a later, unrelated change in the same transaction.
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
  perform set_config('fleetmind.reason', p_reason, true);
  insert into public.user_roles (user_id, role) values (p_user, p_role)
  on conflict do nothing;
  perform set_config('fleetmind.reason', '', true);
end;
$$;

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
  perform set_config('fleetmind.reason', p_reason, true);
  delete from public.user_roles where user_id = p_user and role = p_role;
  perform set_config('fleetmind.reason', '', true);
end;
$$;

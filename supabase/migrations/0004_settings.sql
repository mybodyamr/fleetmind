-- Validated, audited system settings. Written only through set_setting().

create table public.settings (
  key text primary key,
  value jsonb not null,
  updated_by uuid references auth.users (id) on delete set null,
  updated_at timestamptz not null default now()
);

alter table public.settings enable row level security;

create policy settings_select on public.settings for select to authenticated using (true);

revoke all on public.settings from anon;
revoke insert, update, delete, truncate on public.settings from authenticated;

create trigger settings_audit
  after insert or update or delete on public.settings
  for each row execute function public.audit_row_change();

insert into public.settings (key, value) values
  ('assignment.unaccepted_alert_minutes', '15'),
  ('gps.update_interval_seconds', '10'),
  ('gps.stale_after_seconds', '60'),
  ('gps.offline_after_seconds', '300'),
  ('gps.min_accuracy_m', '50'),
  ('alerts.speed_limit_kmh', '120');

-- True when p_value is acceptable for p_key. Unknown keys are never acceptable.
create or replace function public.validate_setting(p_key text, p_value jsonb)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v numeric;
  v_other numeric;
begin
  if p_value is null or jsonb_typeof(p_value) <> 'number' then
    return false;
  end if;
  v := (p_value #>> '{}')::numeric;
  case p_key
    when 'assignment.unaccepted_alert_minutes' then
      return v = trunc(v) and v between 1 and 1440;
    when 'gps.update_interval_seconds' then
      return v = trunc(v) and v between 1 and 3600;
    when 'gps.stale_after_seconds' then
      select (value #>> '{}')::numeric into v_other from public.settings where key = 'gps.offline_after_seconds';
      return v = trunc(v) and v >= 1 and (v_other is null or v < v_other);
    when 'gps.offline_after_seconds' then
      select (value #>> '{}')::numeric into v_other from public.settings where key = 'gps.stale_after_seconds';
      return v = trunc(v) and (v_other is null or v > v_other);
    when 'gps.min_accuracy_m' then
      return v > 0 and v <= 1000;
    when 'alerts.speed_limit_kmh' then
      return v > 0 and v <= 300;
    else
      return false;
  end case;
end;
$$;

create or replace function public.get_setting(p_key text)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select value from public.settings where key = p_key;
$$;

-- Changes a setting. Requires settings.write, a reason, and a valid value; audited by trigger.
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

revoke all on function public.validate_setting(text, jsonb) from public, anon;
revoke all on function public.get_setting(text) from public, anon;
revoke all on function public.set_setting(text, jsonb, text) from public, anon;
grant execute on function public.validate_setting(text, jsonb) to authenticated, service_role;
grant execute on function public.get_setting(text) to authenticated, service_role;
grant execute on function public.set_setting(text, jsonb, text) to authenticated, service_role;

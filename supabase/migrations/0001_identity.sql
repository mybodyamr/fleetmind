-- Identity: profiles, roles, permissions and has_permission().
-- Roles map to permissions by rows in role_permissions, never by code.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.roles (
  name text primary key,
  description text not null
);

create table public.permissions (
  code text primary key,
  description text not null
);

create table public.role_permissions (
  role text not null references public.roles (name) on update cascade on delete cascade,
  permission text not null references public.permissions (code) on update cascade on delete cascade,
  primary key (role, permission)
);

create table public.user_roles (
  user_id uuid not null references public.profiles (id) on delete cascade,
  role text not null references public.roles (name) on update cascade on delete restrict,
  primary key (user_id, role)
);

create index user_roles_role_idx on public.user_roles (role);

-- Deny by default. Policies arrive in 0002_identity_rls.sql.
alter table public.profiles enable row level security;
alter table public.roles enable row level security;
alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;
alter table public.user_roles enable row level security;

-- Reference data.
insert into public.roles (name, description) values
  ('system_admin', 'مدير النظام'),
  ('fleet_manager', 'مدير الأسطول'),
  ('dispatcher', 'مسؤول الحركة'),
  ('supervisor', 'المشرف'),
  ('driver', 'السائق'),
  ('maintenance', 'مسؤول الصيانة'),
  ('finance', 'مسؤول التقارير والمالية');

insert into public.permissions (code, description) values
  ('users.manage', 'إدارة المستخدمين والأدوار'),
  ('settings.write', 'تعديل إعدادات النظام'),
  ('audit.read', 'قراءة سجل التدقيق'),
  ('vehicles.read', 'عرض السيارات'),
  ('vehicles.write', 'إنشاء وتعديل السيارات'),
  ('vehicles.assign_in_maintenance', 'إسناد سيارة في الصيانة (استثناء موثق)'),
  ('drivers.read', 'عرض السائقين'),
  ('drivers.write', 'إنشاء وتعديل السائقين'),
  ('fleet.pair', 'ربط وتبديل السائق والسيارة'),
  ('tasks.read', 'عرض كل المهام'),
  ('tasks.read_own', 'عرض مهام السائق نفسه'),
  ('tasks.create', 'إنشاء المهام'),
  ('tasks.assign', 'إسناد المهام'),
  ('tasks.reassign', 'إعادة إسناد المهام'),
  ('tasks.respond_own', 'قبول أو رفض مهام السائق نفسه'),
  ('tracking.read', 'عرض التتبع'),
  ('tracking.write_own', 'إرسال موقع السائق نفسه'),
  ('maintenance.read', 'عرض الصيانة والأعطال'),
  ('maintenance.write', 'تسجيل الصيانة والأعطال'),
  ('finance.read', 'عرض الوقود والمصروفات'),
  ('finance.write', 'تسجيل الوقود والمصروفات'),
  ('reports.read', 'عرض التقارير'),
  ('reports.export', 'تصدير التقارير');

-- system_admin: everything.
insert into public.role_permissions (role, permission)
  select 'system_admin', code from public.permissions;

-- fleet_manager: everything except user management and the driver-only permissions.
insert into public.role_permissions (role, permission)
  select 'fleet_manager', code from public.permissions
  where code not in ('users.manage', 'tasks.read_own', 'tasks.respond_own', 'tracking.write_own');

insert into public.role_permissions (role, permission) values
  ('dispatcher', 'vehicles.read'),
  ('dispatcher', 'drivers.read'),
  ('dispatcher', 'tasks.read'),
  ('dispatcher', 'tasks.create'),
  ('dispatcher', 'tasks.assign'),
  ('dispatcher', 'tasks.reassign'),
  ('dispatcher', 'fleet.pair'),
  ('dispatcher', 'tracking.read'),
  ('dispatcher', 'reports.read'),
  ('supervisor', 'vehicles.read'),
  ('supervisor', 'drivers.read'),
  ('supervisor', 'tasks.read'),
  ('supervisor', 'tracking.read'),
  ('supervisor', 'maintenance.read'),
  ('supervisor', 'reports.read'),
  ('driver', 'tasks.read_own'),
  ('driver', 'tasks.respond_own'),
  ('driver', 'tracking.write_own'),
  ('maintenance', 'vehicles.read'),
  ('maintenance', 'maintenance.read'),
  ('maintenance', 'maintenance.write'),
  ('finance', 'vehicles.read'),
  ('finance', 'finance.read'),
  ('finance', 'finance.write'),
  ('finance', 'reports.read'),
  ('finance', 'reports.export');

-- True when the calling user is an active account holding a role that grants p_code.
-- Anonymous callers, unknown codes and inactive accounts all return false.
create or replace function public.has_permission(p_code text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    join public.user_roles ur on ur.user_id = p.id
    join public.role_permissions rp on rp.role = ur.role
    where p.id = auth.uid()
      and p.active
      and rp.permission = p_code
  );
$$;

revoke all on function public.has_permission(text) from public;
grant execute on function public.has_permission(text) to anon, authenticated, service_role;

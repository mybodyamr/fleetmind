begin;
select plan(15);

select set_config('tests.admin', tests.create_user('system_admin')::text, true);
select set_config('tests.admin2', tests.create_user('system_admin')::text, true);
select set_config('tests.driver', tests.create_user('driver')::text, true);
select set_config('tests.dispatcher', tests.create_user('dispatcher')::text, true);
select set_config('tests.nobody', tests.create_user(null)::text, true);

-- 1. standing guard for every later phase: no public table may lack RLS
select is_empty(
  $$select tablename from pg_tables where schemaname = 'public' and not rowsecurity$$,
  'every public table has row level security');

-- 2. anonymous callers cannot read identity tables at all
select tests.as_anon();
select throws_ok($$select * from public.roles$$, '42501', null, 'anon cannot read roles');

-- 3-4. a driver sees only their own role rows
select tests.as_user(current_setting('tests.driver')::uuid);
select is((select count(*)::int from public.user_roles where user_id <> auth.uid()), 0,
  'driver cannot see other users'' roles');
select is((select count(*)::int from public.user_roles where user_id = auth.uid()), 1,
  'driver sees their own role');

-- 5. a dispatcher sees only their own profile
select tests.as_user(current_setting('tests.dispatcher')::uuid);
select is((select count(*)::int from public.profiles), 1, 'dispatcher sees only their own profile');

-- 6-7, 15. no permission, no role changes
select tests.as_user(current_setting('tests.driver')::uuid);
select throws_ok(
  format($$select public.assign_role(%L, 'supervisor', 'try')$$, current_setting('tests.nobody')),
  '42501', null, 'driver cannot call assign_role');
select throws_ok(
  format($$select public.revoke_role(%L, 'driver', 'try')$$, current_setting('tests.driver')),
  '42501', null, 'driver cannot call revoke_role');
select throws_ok(
  format($$insert into public.user_roles (user_id, role) values (%L, 'system_admin')$$, current_setting('tests.driver')),
  '42501', null, 'driver cannot write user_roles directly');

-- 8-11. system_admin can assign, but must give a reason
select tests.as_user(current_setting('tests.admin')::uuid);
select lives_ok(
  format($$select public.assign_role(%L, 'supervisor', 'promoted')$$, current_setting('tests.nobody')),
  'system_admin can assign a role');
select is(
  (select count(*)::int from public.user_roles where user_id = current_setting('tests.nobody')::uuid and role = 'supervisor'),
  1, 'the assigned role exists');
select throws_ok(
  format($$select public.assign_role(%L, 'finance', '  ')$$, current_setting('tests.nobody')),
  '22023', null, 'blank reason is rejected');
select throws_ok(
  format($$select public.assign_role(%L, 'finance', null)$$, current_setting('tests.nobody')),
  '22023', null, 'null reason is rejected');

-- 12-13. revoking
select lives_ok(
  format($$select public.revoke_role(%L, 'supervisor', 'back to nothing')$$, current_setting('tests.nobody')),
  'system_admin can revoke a role');
select is(
  (select count(*)::int from public.user_roles where user_id = current_setting('tests.nobody')::uuid),
  0, 'the revoked role is gone');

-- 14. the last active system_admin cannot be removed (would lock everyone out)
select public.revoke_role(current_setting('tests.admin2')::uuid, 'system_admin', 'cleanup');
select throws_ok(
  format($$select public.revoke_role(%L, 'system_admin', 'oops')$$, current_setting('tests.admin')),
  '55000', null, 'last system_admin cannot be revoked');

select tests.reset();
select * from finish();
rollback;

begin;
select plan(13);

select set_config('tests.admin', tests.create_user('system_admin')::text, true);
select set_config('tests.admin2', tests.create_user('system_admin')::text, true);
select set_config('tests.driver', tests.create_user('driver')::text, true);

-- 1-2. standing guard for every later migration: which public functions each API role may execute
select is_empty(
  $$select p.oid::regprocedure::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.prokind = 'f'
       and has_function_privilege('anon', p.oid, 'execute') and p.proname <> 'has_permission'$$,
  'anon can execute only has_permission');
select is_empty(
  $$select p.oid::regprocedure::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.prokind = 'f'
       and has_function_privilege('authenticated', p.oid, 'execute')
       and p.proname not in ('has_permission', 'my_permissions', 'assign_role', 'revoke_role',
                             'set_profile_active', 'get_setting', 'set_setting', 'validate_setting')$$,
  'authenticated can execute only the documented API functions');

-- 3-5. profiles and role_permissions cannot be written directly, not even by a user manager
select tests.as_user(current_setting('tests.driver')::uuid);
select throws_ok($$update public.profiles set active = false$$, '42501', null, 'driver cannot update profiles');
select tests.as_user(current_setting('tests.admin')::uuid);
select throws_ok($$update public.profiles set active = false$$, '42501', null,
  'even system_admin cannot update profiles directly');
select throws_ok($$delete from public.role_permissions$$, '42501', null,
  'even system_admin cannot delete role_permissions directly');

-- 6-7. set_profile_active needs the permission and a reason
select tests.as_user(current_setting('tests.driver')::uuid);
select throws_ok(
  format($$select public.set_profile_active(%L, false, 'try')$$, current_setting('tests.driver')),
  '42501', null, 'driver cannot call set_profile_active');
select tests.as_user(current_setting('tests.admin')::uuid);
select throws_ok(
  format($$select public.set_profile_active(%L, false, '  ')$$, current_setting('tests.driver')),
  '22023', null, 'a blank reason is rejected');

-- 8-11. deactivating works, serializes on the admin guard lock, is audited, and takes effect at once
select lives_ok(
  format($$select public.set_profile_active(%L, false, 'left company')$$, current_setting('tests.driver')),
  'system_admin can deactivate an account');
select ok(
  exists (select 1 from pg_locks
          where locktype = 'advisory' and pid = pg_backend_pid()
            and ((classid::bigint << 32) | objid::bigint) = hashtextextended('fleetmind.system_admin_guard', 0)),
  'set_profile_active takes the admin guard lock');
select is(
  (select reason from public.audit_log
    where entity = 'profiles' and action = 'UPDATE' and entity_id = current_setting('tests.driver')::uuid),
  'left company', 'the deactivation is audited with its reason');
select tests.as_user(current_setting('tests.driver')::uuid);
select is(public.has_permission('tasks.read_own'), false, 'a deactivated account loses its permissions at once');

-- 12-13. the last active system_admin cannot be deactivated
select tests.as_user(current_setting('tests.admin')::uuid);
select lives_ok(
  format($$select public.set_profile_active(%L, false, 'second admin leaves')$$, current_setting('tests.admin2')),
  'a system_admin can be deactivated while another stays active');
select throws_ok(
  format($$select public.set_profile_active(%L, false, 'oops')$$, current_setting('tests.admin')),
  '55000', null, 'the last active system_admin cannot be deactivated');

select tests.reset();
select * from finish();
rollback;

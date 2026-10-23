begin;
select plan(14);

select set_config('tests.admin', tests.create_user('system_admin')::text, true);
select set_config('tests.dispatcher', tests.create_user('dispatcher')::text, true);
select set_config('tests.driver', tests.create_user('driver')::text, true);

-- 1-3, 5-7. invalid changes are rejected with 22023
select tests.as_user(current_setting('tests.admin')::uuid);
select throws_ok($$select public.set_setting('assignment.unaccepted_alert_minutes', '0'::jsonb, 'r')$$,
  '22023', null, 'a zero alert time is rejected');
select throws_ok($$select public.set_setting('gps.update_interval_seconds', '"abc"'::jsonb, 'r')$$,
  '22023', null, 'a non-numeric value is rejected');
select throws_ok($$select public.set_setting('no.such.setting', '1'::jsonb, 'r')$$,
  '22023', null, 'an unknown key is rejected');

-- 4. permission
select tests.as_user(current_setting('tests.dispatcher')::uuid);
select throws_ok($$select public.set_setting('gps.update_interval_seconds', '5'::jsonb, 'r')$$,
  '42501', null, 'dispatcher cannot change settings');

select tests.as_user(current_setting('tests.admin')::uuid);
select throws_ok($$select public.set_setting('gps.update_interval_seconds', '5'::jsonb, '  ')$$,
  '22023', null, 'a blank reason is rejected');
select throws_ok($$select public.set_setting('gps.offline_after_seconds', '30'::jsonb, 'r')$$,
  '22023', null, 'offline_after below stale_after is rejected');
select throws_ok($$select public.set_setting('gps.stale_after_seconds', '300'::jsonb, 'r')$$,
  '22023', null, 'stale_after equal to offline_after is rejected');

-- 8-10, 14. a valid change is applied and audited
select lives_ok($$select public.set_setting('gps.update_interval_seconds', '5'::jsonb, 'tuning')$$,
  'a valid change is accepted');
select is(public.get_setting('gps.update_interval_seconds'), '5'::jsonb, 'get_setting returns the new value');
select is(
  (select reason from public.audit_log where entity = 'settings' and action = 'UPDATE'
     and new_data ->> 'key' = 'gps.update_interval_seconds'),
  'tuning', 'the change is audited with its reason');
select is((select updated_by from public.settings where key = 'gps.update_interval_seconds'),
  current_setting('tests.admin')::uuid, 'updated_by records the user');

-- 11-12. any signed-in user can read defaults but cannot write directly
select tests.as_user(current_setting('tests.driver')::uuid);
select is(public.get_setting('gps.stale_after_seconds'), '60'::jsonb, 'default stale_after_seconds is 60');
select throws_ok($$update public.settings set value = '1'::jsonb$$, '42501', null,
  'direct writes to settings are refused');

-- 13. anonymous callers see nothing
select tests.as_anon();
select throws_ok($$select * from public.settings$$, '42501', null, 'anon cannot read settings');

select tests.reset();
select * from finish();
rollback;

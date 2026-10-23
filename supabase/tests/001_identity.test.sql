begin;
select plan(7);

select set_config('tests.nobody', tests.create_user(null)::text, true);
select set_config('tests.manager', tests.create_user('fleet_manager')::text, true);
select set_config('tests.driver', tests.create_user('driver')::text, true);
select set_config('tests.dispatcher', tests.create_user('dispatcher')::text, true);
select set_config('tests.inactive', tests.create_user('fleet_manager', false)::text, true);

select tests.as_anon();
select is(public.has_permission('vehicles.read'), false, 'anon has no permission');

select tests.as_user(current_setting('tests.nobody')::uuid);
select is(public.has_permission('vehicles.read'), false, 'user without a role has no permission');

select tests.as_user(current_setting('tests.manager')::uuid);
select is(public.has_permission('vehicles.write'), true, 'fleet_manager can write vehicles');

select tests.as_user(current_setting('tests.driver')::uuid);
select is(
  array[public.has_permission('tasks.read_own'), public.has_permission('vehicles.write')],
  array[true, false],
  'driver can read own tasks but cannot write vehicles');

select tests.as_user(current_setting('tests.dispatcher')::uuid);
select is(public.has_permission('settings.write'), false, 'dispatcher cannot write settings');

select tests.as_user(current_setting('tests.inactive')::uuid);
select is(public.has_permission('vehicles.write'), false, 'inactive fleet_manager has no permission');

select tests.as_user(current_setting('tests.manager')::uuid);
select is(public.has_permission('no.such.permission'), false, 'unknown permission code is false, not an error');

select tests.reset();
select * from finish();
rollback;

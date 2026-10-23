begin;
select plan(5);

select set_config('tests.driver', tests.create_user('driver')::text, true);
select set_config('tests.manager', tests.create_user('fleet_manager')::text, true);
select set_config('tests.inactive', tests.create_user('fleet_manager', false)::text, true);
select set_config('tests.nobody', tests.create_user(null)::text, true);

select tests.as_user(current_setting('tests.driver')::uuid);
select is(
  (select array_agg(p order by p) from public.my_permissions() p),
  array['tasks.read_own', 'tasks.respond_own', 'tracking.write_own'],
  'driver gets exactly the driver permissions');

select tests.as_user(current_setting('tests.manager')::uuid);
select ok(exists (select 1 from public.my_permissions() p where p = 'vehicles.write'),
  'fleet_manager includes vehicles.write');
select is(
  (select count(*)::int from public.my_permissions()),
  (select count(*)::int from public.permissions where public.has_permission(code)),
  'my_permissions agrees with has_permission for every code');

select tests.as_user(current_setting('tests.inactive')::uuid);
select is_empty($$select * from public.my_permissions()$$, 'inactive account gets no permissions');

select tests.as_user(current_setting('tests.nobody')::uuid);
select is_empty($$select * from public.my_permissions()$$, 'user without a role gets no permissions');

select tests.reset();
select * from finish();
rollback;

begin;
select plan(13);

select set_config('tests.admin', tests.create_user('system_admin')::text, true);
select set_config('tests.driver', tests.create_user('driver')::text, true);
select set_config('tests.dispatcher', tests.create_user('dispatcher')::text, true);
select set_config('tests.nobody', tests.create_user(null)::text, true);
select set_config('tests.nobody2', tests.create_user(null)::text, true);

select tests.as_user(current_setting('tests.admin')::uuid);
select public.assign_role(current_setting('tests.nobody')::uuid, 'supervisor', 'promoted');

-- 1-3. assign_role leaves a row with the actor, the reason and the time
select is(
  (select actor_id from public.audit_log
    where entity = 'user_roles' and action = 'INSERT'
      and new_data ->> 'user_id' = current_setting('tests.nobody') and new_data ->> 'role' = 'supervisor'),
  current_setting('tests.admin')::uuid, 'assign_role records who did it');
select is(
  (select reason from public.audit_log
    where entity = 'user_roles' and action = 'INSERT'
      and new_data ->> 'user_id' = current_setting('tests.nobody') and new_data ->> 'role' = 'supervisor'),
  'promoted', 'assign_role records why');
select ok(
  (select at from public.audit_log
    where entity = 'user_roles' and action = 'INSERT'
      and new_data ->> 'user_id' = current_setting('tests.nobody') and new_data ->> 'role' = 'supervisor')
  between now() - interval '1 minute' and now(), 'assign_role records when');

-- 4. revoke_role is audited too, with the old values
select public.revoke_role(current_setting('tests.nobody')::uuid, 'supervisor', 'demoted');
select is(
  (select reason from public.audit_log
    where entity = 'user_roles' and action = 'DELETE' and old_data ->> 'user_id' = current_setting('tests.nobody')),
  'demoted', 'revoke_role is audited with its reason');

-- 5-6. append-only for API roles, even system_admin
select throws_ok($$update public.audit_log set reason = 'x'$$, '42501', null, 'system_admin cannot update audit_log');
select throws_ok($$delete from public.audit_log$$, '42501', null, 'system_admin cannot delete from audit_log');

-- 7-8. append-only for the privileged runner as well (trigger)
select tests.reset();
select throws_ok($$update public.audit_log set reason = 'x'$$, '55000', null, 'audit_log rejects UPDATE for everyone');
select throws_ok($$delete from public.audit_log$$, '55000', null, 'audit_log rejects DELETE for everyone');

-- 9-10. only audit.read holders can read it
select tests.as_user(current_setting('tests.dispatcher')::uuid);
select is((select count(*)::int from public.audit_log), 0, 'dispatcher reads no audit rows');
select tests.as_user(current_setting('tests.admin')::uuid);
select ok((select count(*) from public.audit_log) > 0, 'system_admin reads audit rows');

-- 11-12. nobody can forge entries through the API
select tests.as_user(current_setting('tests.driver')::uuid);
select throws_ok($$select public.write_audit('FAKE', 'x', null, 'r', '{}'::jsonb)$$, '42501', null,
  'driver cannot call write_audit');
select throws_ok($$insert into public.audit_log (action, entity) values ('FAKE', 'x')$$, '42501', null,
  'driver cannot insert into audit_log');

-- 13. a reason given to one call must not leak onto a later, unrelated change
select tests.as_user(current_setting('tests.admin')::uuid);
select public.assign_role(current_setting('tests.nobody2')::uuid, 'finance', 'first call');
select tests.reset();
insert into public.user_roles (user_id, role) values (current_setting('tests.nobody2')::uuid, 'driver');
select is(
  (select reason from public.audit_log
    where entity = 'user_roles' and action = 'INSERT'
      and new_data ->> 'user_id' = current_setting('tests.nobody2') and new_data ->> 'role' = 'driver'),
  null::text, 'a previous call''s reason does not leak');

select * from finish();
rollback;

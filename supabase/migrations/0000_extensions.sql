-- Extensions required by FleetMind (see plan, Task 0.2).
create extension if not exists postgis with schema extensions;
create extension if not exists btree_gist with schema extensions;
create extension if not exists pg_cron;

begin;
select plan(3);
select has_extension('postgis', 'postgis is installed');
select has_extension('btree_gist', 'btree_gist is installed');
select has_extension('pg_cron', 'pg_cron is installed');
select * from finish();
rollback;

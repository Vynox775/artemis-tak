-- =====================================================================
-- Artemis TAK: auto-delete rooms nobody has used for 24 hours.
-- Run AFTER setup.sql. Open rooms ping last_active every 5 minutes,
-- so only empty rooms age out. Their marks are deleted with them.
-- If the first line errors, turn on "pg_cron" under
-- Database -> Extensions, then run this again.
-- =====================================================================
create extension if not exists pg_cron;

select cron.unschedule('artemis-room-cleanup')
where exists (select 1 from cron.job where jobname = 'artemis-room-cleanup');

select cron.schedule(
  'artemis-room-cleanup',
  '0 * * * *',
  $$ delete from public.rooms where last_active < now() - interval '24 hours' $$
);
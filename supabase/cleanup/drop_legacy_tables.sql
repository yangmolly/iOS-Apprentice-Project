-- OPTIONAL, DESTRUCTIVE. Not a migration; it lives outside supabase/migrations/
-- so `supabase db push` never applies it.
--
-- Drops the legacy tables and views that 20261120000000_studyspot_v2.sql replaced.
-- Only run this yourself, after confirming the data was copied:
--   select count(*) from public.favorites;      -- compare with saved_spots where list = 'favorite'
--   select count(*) from public.event_members;  -- compare with event_rsvps
--
-- The app no longer reads or writes any of these objects.

begin;

drop view if exists public.spot_ratings;
drop view if exists public.event_member_counts;
drop table if exists public.favorites;
drop table if exists public.event_members;

commit;

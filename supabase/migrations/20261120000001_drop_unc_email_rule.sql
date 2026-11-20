-- Allow any email domain to sign up.
-- Removes the @unc.edu check added in 20261120000000_studyspot_v2.sql.
-- Safe to run whether or not that migration has been applied yet. No data is touched.

drop trigger if exists enforce_unc_email on auth.users;
drop function if exists public.enforce_unc_email();

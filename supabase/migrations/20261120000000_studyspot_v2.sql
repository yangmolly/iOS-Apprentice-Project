-- StudySpot migration 3: v2 schema.
-- Run AFTER 20261108000000_seed_and_views.sql.
--
-- Additive and non-destructive: nothing is dropped and no existing rows are deleted.
-- The legacy tables `favorites` and `event_members` are copied into the new
-- `saved_spots` and `event_rsvps` tables and left in place. To drop them later,
-- run supabase/cleanup/drop_legacy_tables.sql yourself.
--
-- Wrapped in a transaction: if any step fails, nothing is applied.

begin;

create extension if not exists pg_trgm with schema extensions;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

do $$ begin
  create type public.noise_level as enum ('quiet', 'moderate', 'loud');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.seating_type as enum ('solo', 'group', 'both');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.review_bucket as enum ('liked', 'fine', 'disliked');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.saved_list as enum ('want_to_go', 'favorite');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- study_spots: environment attributes, hours, creator, cached rating stats
-- ---------------------------------------------------------------------------

alter table public.study_spots
  add column if not exists created_by   uuid references public.profiles (id) on delete set null default auth.uid(),
  add column if not exists noise_level  public.noise_level,
  add column if not exists has_outlets  boolean,
  add column if not exists has_wifi     boolean,
  add column if not exists seating      public.seating_type,
  add column if not exists opens_at     time,
  add column if not exists closes_at    time,
  add column if not exists open_24h     boolean not null default false,
  add column if not exists avg_rating   numeric(3,1),
  add column if not exists review_count integer not null default 0;

-- Spots persist once added: insert and creator-update only, no delete policy.
drop policy if exists "users add spots" on public.study_spots;
create policy "users add spots" on public.study_spots
  for insert to authenticated with check (auth.uid() = created_by);

drop policy if exists "creators edit spots" on public.study_spots;
create policy "creators edit spots" on public.study_spots
  for update to authenticated using (auth.uid() = created_by) with check (auth.uid() = created_by);

-- ---------------------------------------------------------------------------
-- reviews: Beli-style bucket + 0-10 score, environment attributes, one per user per spot
-- ---------------------------------------------------------------------------

alter table public.reviews
  add column if not exists bucket      public.review_bucket,
  add column if not exists score       numeric(3,1) check (score between 0 and 10),
  add column if not exists noise_level public.noise_level,
  add column if not exists has_outlets boolean,
  add column if not exists has_wifi    boolean,
  add column if not exists seating     public.seating_type,
  add column if not exists updated_at  timestamptz not null default now();

-- New reviews use bucket + score; the legacy 1-5 rating becomes optional.
alter table public.reviews alter column rating drop not null;

-- Backfill score and bucket for any legacy 1-5 star reviews (fills new columns only).
update public.reviews
set score  = rating * 2,
    bucket = case when rating >= 4 then 'liked'::public.review_bucket
                  when rating = 3  then 'fine'::public.review_bucket
                  else 'disliked'::public.review_bucket end
where score is null and rating is not null;

-- One review per user per spot. Fail clearly (instead of deleting anything) if duplicates exist.
do $$
declare dup_count integer;
begin
  select count(*) into dup_count from (
    select 1 from public.reviews group by user_id, spot_id having count(*) > 1
  ) d;
  if dup_count > 0 then
    raise exception
      'Found % user/spot pairs with more than one review. Resolve them before applying this migration: select user_id, spot_id, count(*) from public.reviews group by 1, 2 having count(*) > 1;',
      dup_count;
  end if;
end $$;

create unique index if not exists reviews_user_spot_key on public.reviews (user_id, spot_id);

create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists reviews_touch_updated_at on public.reviews;
create trigger reviews_touch_updated_at
  before update on public.reviews
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Keep each spot's average rating, review count and consensus attributes current
-- ---------------------------------------------------------------------------

create or replace function public.refresh_spot_stats(p_spot_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.study_spots s
  set avg_rating   = agg.avg_score,
      review_count = agg.cnt,
      -- Consensus from reviews; fall back to the creator's values when reviewers left them blank.
      noise_level  = coalesce(agg.noise, s.noise_level),
      seating      = coalesce(agg.seat, s.seating),
      has_outlets  = coalesce(agg.outlets, s.has_outlets),
      has_wifi     = coalesce(agg.wifi, s.has_wifi)
  from (
    select
      round(avg(r.score), 1)                              as avg_score,
      count(r.id)::int                                    as cnt,
      mode() within group (order by r.noise_level)        as noise,
      mode() within group (order by r.seating)            as seat,
      case when count(r.has_outlets) = 0 then null
           else avg(r.has_outlets::int) >= 0.5 end        as outlets,
      case when count(r.has_wifi) = 0 then null
           else avg(r.has_wifi::int) >= 0.5 end           as wifi
    from public.reviews r
    where r.spot_id = p_spot_id and r.score is not null
  ) agg
  where s.id = p_spot_id;
end;
$$;

create or replace function public.on_review_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op in ('INSERT', 'UPDATE') then
    perform public.refresh_spot_stats(new.spot_id);
  end if;
  if tg_op = 'DELETE' or (tg_op = 'UPDATE' and old.spot_id is distinct from new.spot_id) then
    perform public.refresh_spot_stats(old.spot_id);
  end if;
  return null;
end;
$$;

drop trigger if exists reviews_refresh_spot_stats on public.reviews;
create trigger reviews_refresh_spot_stats
  after insert or update or delete on public.reviews
  for each row execute function public.on_review_change();

-- Initialize stats for existing spots.
select public.refresh_spot_stats(id) from public.study_spots;

-- ---------------------------------------------------------------------------
-- Near-duplicate spot prevention
-- ---------------------------------------------------------------------------

create or replace function public.haversine_m(lat1 float8, lng1 float8, lat2 float8, lng2 float8)
returns float8 language sql immutable as $$
  select 2 * 6371000 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)
  ));
$$;

-- Candidates for the client's "Did you mean...?" prompt: nearby spots with a similar name.
create or replace function public.find_similar_spots(p_name text, p_lat float8, p_lng float8)
returns setof public.study_spots
language sql stable set search_path = public, extensions as $$
  select s.*
  from public.study_spots s
  where public.haversine_m(s.latitude, s.longitude, p_lat, p_lng) <= 75
    and similarity(lower(s.name), lower(p_name)) >= 0.4
  order by similarity(lower(s.name), lower(p_name)) desc
  limit 5;
$$;

grant execute on function public.find_similar_spots(text, float8, float8) to authenticated;

-- Digits in a name ("Rm 206", "Cube #2") distinguish otherwise identical names.
create or replace function public.name_digits(p_name text)
returns text language sql immutable as $$
  select regexp_replace(coalesce(p_name, ''), '[^0-9]', '', 'g');
$$;

-- Hard server-side block: a spot within 75 m whose name is very similar and has the same numbers.
-- Distance alone is not enough: distinct rooms in one building share coordinates.
create or replace function public.prevent_duplicate_spot() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare existing_name text;
begin
  select s.name into existing_name
  from public.study_spots s
  where public.haversine_m(s.latitude, s.longitude, new.latitude, new.longitude) <= 75
    and similarity(lower(s.name), lower(new.name)) >= 0.7
    and public.name_digits(s.name) = public.name_digits(new.name)
  limit 1;

  if existing_name is not null then
    raise exception 'duplicate_spot: "%" already exists nearby', existing_name
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists study_spots_prevent_duplicate on public.study_spots;
create trigger study_spots_prevent_duplicate
  before insert on public.study_spots
  for each row execute function public.prevent_duplicate_spot();

-- ---------------------------------------------------------------------------
-- events: end time, description, coordinates
-- ---------------------------------------------------------------------------

alter table public.events
  add column if not exists ends_at     timestamptz,
  add column if not exists description text,
  add column if not exists latitude    float8,
  add column if not exists longitude   float8;

do $$ begin
  alter table public.events add constraint events_time_order
    check (ends_at is null or starts_at is null or ends_at >= starts_at);
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- event_rsvps (replaces event_members)
-- ---------------------------------------------------------------------------

create table if not exists public.event_rsvps (
  event_id   uuid not null references public.events (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

insert into public.event_rsvps (event_id, user_id, created_at)
select event_id, user_id, joined_at from public.event_members
on conflict do nothing;

create index if not exists event_rsvps_user_idx on public.event_rsvps (user_id);

alter table public.event_rsvps enable row level security;

drop policy if exists "rsvps readable by signed-in users" on public.event_rsvps;
create policy "rsvps readable by signed-in users" on public.event_rsvps
  for select to authenticated using (true);
drop policy if exists "users rsvp as themselves" on public.event_rsvps;
create policy "users rsvp as themselves" on public.event_rsvps
  for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "users cancel own rsvp" on public.event_rsvps;
create policy "users cancel own rsvp" on public.event_rsvps
  for delete to authenticated using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- saved_spots (replaces favorites): want-to-go and favorites lists
-- ---------------------------------------------------------------------------

create table if not exists public.saved_spots (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  spot_id    uuid not null references public.study_spots (id) on delete cascade,
  list       public.saved_list not null,
  created_at timestamptz not null default now(),
  primary key (user_id, spot_id, list)
);

insert into public.saved_spots (user_id, spot_id, list, created_at)
select user_id, spot_id, 'favorite', created_at from public.favorites
on conflict do nothing;

create index if not exists saved_spots_user_idx on public.saved_spots (user_id, list);

alter table public.saved_spots enable row level security;

drop policy if exists "saved readable by signed-in users" on public.saved_spots;
create policy "saved readable by signed-in users" on public.saved_spots
  for select to authenticated using (true);
drop policy if exists "users save own spots" on public.saved_spots;
create policy "users save own spots" on public.saved_spots
  for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "users unsave own spots" on public.saved_spots;
create policy "users unsave own spots" on public.saved_spots
  for delete to authenticated using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Only @unc.edu addresses can sign up (the app validates too)
-- ---------------------------------------------------------------------------

create or replace function public.enforce_unc_email() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.email is null or lower(new.email) not like '%@unc.edu' then
    raise exception 'Only @unc.edu email addresses can be used.' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_unc_email on auth.users;
create trigger enforce_unc_email
  before insert or update of email on auth.users
  for each row execute function public.enforce_unc_email();

-- ---------------------------------------------------------------------------
-- Realtime: broadcast rating changes
-- ---------------------------------------------------------------------------

do $$ begin
  alter publication supabase_realtime add table public.study_spots;
exception when duplicate_object then null; end $$;

do $$ begin
  alter publication supabase_realtime add table public.reviews;
exception when duplicate_object then null; end $$;

commit;

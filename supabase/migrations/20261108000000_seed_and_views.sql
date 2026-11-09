-- StudySpot migration 2: starter spots, summary views, indexes.
-- Run AFTER 20261107000000_initial_schema.sql.
-- NOTE: coordinates below are approximate. Check each one in Apple/Google Maps and edit if needed.

-- Spot names must be unique so this script is safe to run twice.
alter table public.study_spots
  add constraint study_spots_name_key unique (name);

insert into public.study_spots (name, building, latitude, longitude) values
  ('Davis Library',                'Walter Royal Davis Library', 35.9100, -79.0477),
  ('Davis Collaboration Cube #2',  'Walter Royal Davis Library', 35.9100, -79.0477),
  ('Dey Hall',                     'Dey Hall',                   35.9107, -79.0508),
  ('Sitterson Lobby',              'Sitterson Hall',             35.9097, -79.0510),
  ('Gardner Hall',                 'Gardner Hall',               35.9103, -79.0513)
on conflict (name) do nothing;

-- Average rating + review count per spot (respects the caller's row-level security).
create view public.spot_ratings
with (security_invoker = true) as
select
  s.id as spot_id,
  coalesce(round(avg(r.rating)::numeric, 2), 0) as average_rating,
  count(r.id)::int as review_count
from public.study_spots s
left join public.reviews r on r.spot_id = s.id
group by s.id;

-- How many people joined each event.
create view public.event_member_counts
with (security_invoker = true) as
select
  e.id as event_id,
  count(m.user_id)::int as member_count
from public.events e
left join public.event_members m on m.event_id = e.id
group by e.id;

-- Indexes for the common lookups.
create index if not exists reviews_spot_id_idx      on public.reviews (spot_id, created_at desc);
create index if not exists reviews_user_id_idx      on public.reviews (user_id);
create index if not exists events_category_start_idx on public.events (category, starts_at);
create index if not exists event_members_user_idx   on public.event_members (user_id);
create index if not exists favorites_user_idx       on public.favorites (user_id);

grant select on public.spot_ratings, public.event_member_counts to authenticated;

-- StudySpot initial schema (draft, derived from the current SwiftUI screens)
-- Review before applying: supabase db push (or paste into the SQL editor).

create extension if not exists "pgcrypto";

-- Profiles: one row per auth user (SignUpView collects name + UNC email)
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null,
  email text not null unique,
  created_at timestamptz not null default now()
);

-- Study spots (MapView / FeedbackView locationName)
create table public.study_spots (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  building text,
  latitude double precision not null,
  longitude double precision not null,
  created_at timestamptz not null default now()
);

-- Reviews (FeedbackView: 1-5 rating, liked/disliked tags, 300-char comment)
create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  spot_id uuid not null references public.study_spots (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  liked_tags text[] not null default '{}',
  disliked_tags text[] not null default '{}',
  comments text check (char_length(comments) <= 300),
  created_at timestamptz not null default now()
);

-- Events / study groups (ExploreView: CLE EVENT, STUDY GROUP, FREE FOOD, CLUBS)
create type public.event_category as enum ('cle_event', 'study_group', 'free_food', 'club');

create table public.events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  category public.event_category not null,
  location text not null,
  spot_id uuid references public.study_spots (id) on delete set null,
  starts_at timestamptz,
  created_by uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.event_members (
  event_id uuid not null references public.events (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

-- Favorites (FavoritesView)
create table public.favorites (
  user_id uuid not null references public.profiles (id) on delete cascade,
  spot_id uuid not null references public.study_spots (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, spot_id)
);

-- Create a profile automatically when someone signs up
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, name, email)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'name', ''), new.email);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Row Level Security
alter table public.profiles enable row level security;
alter table public.study_spots enable row level security;
alter table public.reviews enable row level security;
alter table public.events enable row level security;
alter table public.event_members enable row level security;
alter table public.favorites enable row level security;

create policy "profiles readable by signed-in users" on public.profiles
  for select to authenticated using (true);
create policy "users update own profile" on public.profiles
  for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

create policy "spots readable by signed-in users" on public.study_spots
  for select to authenticated using (true);

create policy "reviews readable by signed-in users" on public.reviews
  for select to authenticated using (true);
create policy "users write own reviews" on public.reviews
  for insert to authenticated with check (auth.uid() = user_id);
create policy "users edit own reviews" on public.reviews
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "users delete own reviews" on public.reviews
  for delete to authenticated using (auth.uid() = user_id);

create policy "events readable by signed-in users" on public.events
  for select to authenticated using (true);
create policy "users create own events" on public.events
  for insert to authenticated with check (auth.uid() = created_by);
create policy "creators edit events" on public.events
  for update to authenticated using (auth.uid() = created_by) with check (auth.uid() = created_by);
create policy "creators delete events" on public.events
  for delete to authenticated using (auth.uid() = created_by);

create policy "members readable by signed-in users" on public.event_members
  for select to authenticated using (true);
create policy "users join as themselves" on public.event_members
  for insert to authenticated with check (auth.uid() = user_id);
create policy "users leave as themselves" on public.event_members
  for delete to authenticated using (auth.uid() = user_id);

create policy "users read own favorites" on public.favorites
  for select to authenticated using (auth.uid() = user_id);
create policy "users add own favorites" on public.favorites
  for insert to authenticated with check (auth.uid() = user_id);
create policy "users remove own favorites" on public.favorites
  for delete to authenticated using (auth.uid() = user_id);

-- Replaces the earlier personal_duas.sql design (an admin-only hidden
-- section with per-user grants) with a public one: a shared base
-- collection any reader can see on the home screen, editable only by the
-- admin (see is_admin() in app_sections.sql) from its own screen without a
-- new app build — plus a second, per-user collection each signed-in reader
-- keeps entirely to themselves, synced to their account the same way
-- favourites and bookmarks already are.
--
-- Run this AFTER app_sections.sql. If personal_duas.sql was already run,
-- this drops its tables/functions first — nothing in this app depended on
-- them beyond the screen that is being replaced along with this migration.

drop function if exists public.grant_personal_dua_access(text);
drop function if exists public.revoke_personal_dua_access(uuid);
drop table if exists public.personal_dua_grants;
drop table if exists public.personal_duas;

-- One row, id fixed at 1 so there is only ever one base collection.
create table if not exists public.duas_base (
  id         int primary key default 1 check (id = 1),
  content    text not null default '[]',
  updated_at timestamptz not null default now()
);
alter table public.duas_base enable row level security;

drop policy if exists duas_base_select on public.duas_base;
create policy duas_base_select on public.duas_base
  for select to authenticated, anon
  using (true);

drop policy if exists duas_base_write on public.duas_base;
create policy duas_base_write on public.duas_base
  for all to authenticated
  using (public.is_admin())
  with check (id = 1 and public.is_admin());

grant select on public.duas_base to authenticated, anon;
grant insert, update on public.duas_base to authenticated;

-- One row per reader, entirely their own — what they add here is never
-- visible to anyone else, admin included (no select policy grants it).
create table if not exists public.user_duas (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  content    text not null default '[]',
  updated_at timestamptz not null default now()
);
alter table public.user_duas enable row level security;

drop policy if exists user_duas_all on public.user_duas;
create policy user_duas_all on public.user_duas
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

grant select, insert, update on public.user_duas to authenticated;
revoke all on public.user_duas from anon;

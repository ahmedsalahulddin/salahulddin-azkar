-- Remote control over which sections the home screen shows, and in what order.
--
-- The app treats this as a hint, never as a requirement: if the table cannot be
-- reached it shows everything. A configuration service that can blank the app
-- when it goes down is worse than no configuration service.
--
-- Run once in the Supabase SQL editor.

-- Who may change the configuration. A table rather than a hardcoded email, so
-- the admin can be changed without a migration.
create table if not exists public.app_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.app_admins enable row level security;

-- Readers may check whether they themselves are an admin, and nothing more.
-- Rows are added by the project owner in the SQL editor, never by the client.
create policy "see own admin row" on public.app_admins
  for select to authenticated using (auth.uid() = user_id);

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.app_admins where user_id = auth.uid())
$$;

revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

-- The sections themselves.
create table if not exists public.app_sections (
  key text primary key,
  title text not null,
  enabled boolean not null default true,
  sort_order int not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.app_sections enable row level security;

-- Public on purpose: it is layout, not data, and the app must be able to read
-- it before anyone signs in.
create policy "sections readable" on public.app_sections
  for select to anon, authenticated using (true);

create policy "sections admin write" on public.app_sections
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

grant select on public.app_sections to anon, authenticated;
grant insert, update, delete on public.app_sections to authenticated;

-- Current sections, in the order the app ships with.
insert into public.app_sections (key, title, sort_order) values
  ('quran',     'القرآن الكريم',  1),
  ('adhkar',    'الأذكار',        2),
  ('library',   'المكتبة',        3),
  ('tasbih',    'عداد التسبيح',   4),
  ('deceased',  'الوفيات',        5),
  ('favorites', 'المفضلة',        6),
  ('videos',    'مرئيات',         7)
on conflict (key) do nothing;

-- The videos section stays hidden until the channel has something in it.
update public.app_sections set enabled = false where key = 'videos';

-- ---------------------------------------------------------------------------
-- Make yourself an admin AFTER signing in to the app once, so the account
-- exists to point at:
--
--   insert into public.app_admins (user_id)
--   select id from auth.users where email = 'ahmed.salahulddin@gmail.com'
--   on conflict do nothing;
-- ---------------------------------------------------------------------------

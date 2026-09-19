-- A private dua collection, visible only to the app's admin (see
-- app_sections.sql's is_admin()) by default, with grantable read access for
-- specific other users the admin picks by email — never shipped in the app
-- bundle, never shown to a general reader.
--
-- Run AFTER app_sections.sql (needs is_admin()).

create table if not exists public.personal_duas (
  owner_id   uuid primary key references auth.users(id) on delete cascade,
  content    text not null default '',
  updated_at timestamptz not null default now()
);
alter table public.personal_duas enable row level security;

create table if not exists public.personal_dua_grants (
  owner_id   uuid not null references auth.users(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  email      text,
  granted_at timestamptz not null default now(),
  primary key (owner_id, user_id)
);
alter table public.personal_dua_grants enable row level security;

drop policy if exists personal_duas_select on public.personal_duas;
create policy personal_duas_select on public.personal_duas
  for select to authenticated
  using (
    owner_id = auth.uid()
    or exists (
      select 1 from public.personal_dua_grants g
      where g.owner_id = personal_duas.owner_id and g.user_id = auth.uid()
    )
  );

drop policy if exists personal_duas_write on public.personal_duas;
create policy personal_duas_write on public.personal_duas
  for all to authenticated
  using (owner_id = auth.uid() and public.is_admin())
  with check (owner_id = auth.uid() and public.is_admin());

drop policy if exists personal_dua_grants_select on public.personal_dua_grants;
create policy personal_dua_grants_select on public.personal_dua_grants
  for select to authenticated
  using (owner_id = auth.uid() or user_id = auth.uid());

drop policy if exists personal_dua_grants_write on public.personal_dua_grants;
create policy personal_dua_grants_write on public.personal_dua_grants
  for all to authenticated
  using (owner_id = auth.uid() and public.is_admin())
  with check (owner_id = auth.uid() and public.is_admin());

grant select, insert, update on public.personal_duas to authenticated;
grant select, insert, delete on public.personal_dua_grants to authenticated;
revoke all on public.personal_duas, public.personal_dua_grants from anon;

-- Looks a reader up by email so the admin can grant access without knowing
-- a uuid. security definer because auth.users isn't otherwise readable.
create or replace function public.grant_personal_dua_access(p_email text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  target uuid;
begin
  if not public.is_admin() then raise exception 'not_admin'; end if;
  select id into target from auth.users where email = p_email limit 1;
  if target is null then raise exception 'user_not_found'; end if;
  insert into public.personal_dua_grants (owner_id, user_id, email)
  values (auth.uid(), target, p_email)
  on conflict (owner_id, user_id) do nothing;
end;
$$;
revoke all on function public.grant_personal_dua_access(text) from public, anon;
grant execute on function public.grant_personal_dua_access(text) to authenticated;

create or replace function public.revoke_personal_dua_access(p_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'not_admin'; end if;
  delete from public.personal_dua_grants
   where owner_id = auth.uid() and user_id = p_user_id;
end;
$$;
revoke all on function public.revoke_personal_dua_access(uuid) from public, anon;
grant execute on function public.revoke_personal_dua_access(uuid) to authenticated;

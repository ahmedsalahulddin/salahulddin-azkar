-- Lets an admin manage the admin list from the app (Account → Admin →
-- Admins), instead of the SQL editor. Builds on app_admins / is_admin() from
-- app_sections.sql.
--
-- Every function checks is_admin() itself: the table's RLS still only lets a
-- reader see their own row, so these are the only way in.
--
-- Run once in the Supabase SQL editor.

-- Who is an admin, with the email each account signed in with.
create or replace function public.admin_list()
returns table (user_id uuid, email text, added_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then raise exception 'not_admin'; end if;
  return query
    select a.user_id, u.email::text, a.created_at
    from public.app_admins a
    join auth.users u on u.id = a.user_id
    order by a.created_at;
end;
$$;

-- Adds the account with this email. The person must have signed in once.
-- Returns false when no account has that email.
create or replace function public.admin_add(target_email text)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  target uuid;
begin
  if not public.is_admin() then raise exception 'not_admin'; end if;
  select id into target from auth.users
    where lower(email) = lower(trim(target_email))
    order by created_at
    limit 1;
  if target is null then return false; end if;
  insert into public.app_admins (user_id) values (target)
    on conflict do nothing;
  return true;
end;
$$;

-- Removes an admin. Never the caller themselves, so the list can't be emptied
-- by accident and nobody locks themselves out.
create or replace function public.admin_remove(target uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then raise exception 'not_admin'; end if;
  if target = auth.uid() then raise exception 'cannot_remove_self'; end if;
  delete from public.app_admins where user_id = target;
end;
$$;

revoke all on function public.admin_list() from public, anon;
revoke all on function public.admin_add(text) from public, anon;
revoke all on function public.admin_remove(uuid) from public, anon;
grant execute on function public.admin_list() to authenticated;
grant execute on function public.admin_add(text) to authenticated;
grant execute on function public.admin_remove(uuid) to authenticated;

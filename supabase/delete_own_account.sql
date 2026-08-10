-- Lets a signed-in reader delete their own account, and nobody else's.
--
-- Supabase deliberately blocks clients from touching auth.users, so deletion
-- has to go through a function that runs with elevated rights. The safety of
-- that arrangement rests on two things, both below:
--
--   * the function ignores any argument and deletes auth.uid() — the caller —
--     so it cannot be pointed at another account;
--   * execute is granted only to `authenticated`, never to `anon`, so an
--     anonymous request cannot reach it at all.
--
-- Run once in the Supabase SQL editor.

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
begin
  if caller is null then
    raise exception 'not authenticated';
  end if;

  -- Deleting the auth row cascades to anything keyed on it.
  delete from auth.users where id = caller;
end;
$$;

revoke all on function public.delete_own_account() from public;
revoke all on function public.delete_own_account() from anon;
grant execute on function public.delete_own_account() to authenticated;

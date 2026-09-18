-- Lets a teacher stay out of the public directory while still reachable by
-- their own code. Run AFTER tahfeez_messages.sql. Safe to run more than once.

alter table public.tahfeez_profiles
  add column if not exists listed boolean not null default true;

-- Only listed teachers are open to everyone; an unlisted one is visible to
-- those already related to them (a request by code makes them related).
drop policy if exists tahfeez_profiles_select on public.tahfeez_profiles;
create policy tahfeez_profiles_select on public.tahfeez_profiles
  for select to authenticated
  using (
    user_id = auth.uid() or (role = 'teacher' and listed) or public.is_admin()
      or public.tahfeez_related(user_id)
  );

drop function if exists public.update_teacher_profile(text, text, text, int, text, text[], text);
create or replace function public.update_teacher_profile(
  p_bio text, p_city text, p_plan text, p_free int, p_price text,
  p_languages text[], p_teaches text, p_listed boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_teacher() then raise exception 'not_teacher'; end if;
  if p_teaches not in ('male', 'female', 'both') then raise exception 'bad_gender'; end if;
  update public.tahfeez_profiles
     set bio = nullif(trim(p_bio), ''),
         city = nullif(trim(p_city), ''),
         plan_period = p_plan,
         free_sessions = p_free,
         price_note = nullif(trim(p_price), ''),
         languages = coalesce(p_languages, '{}'),
         teaches_gender = p_teaches,
         listed = coalesce(p_listed, true),
         updated_at = now()
   where user_id = auth.uid();
end;
$$;
revoke all on function public.update_teacher_profile(text, text, text, int, text, text[], text, boolean)
  from public, anon;
grant execute on function public.update_teacher_profile(text, text, text, int, text, text[], text, boolean)
  to authenticated;

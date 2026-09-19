-- A teacher's country and whether they teach children, so the directory can
-- filter on both; and a small in-app notice channel so a teacher hears when a
-- student withdraws a pending request (the row itself is deleted, so nothing
-- else would have told them).
--
-- Run AFTER tahfeez_listed.sql. Safe to run more than once.

-- ---------------------------------------------------------------------------
alter table public.tahfeez_profiles
  add column if not exists country          text,
  add column if not exists teaches_children boolean not null default false;

drop function if exists public.update_teacher_profile(text, text, text, int, text, text[], text, boolean);
create or replace function public.update_teacher_profile(
  p_bio text, p_city text, p_plan text, p_free int, p_price text,
  p_languages text[], p_teaches text, p_listed boolean,
  p_country text, p_children boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_teacher() then raise exception 'not_teacher'; end if;
  if p_teaches not in ('male', 'female', 'both') then raise exception 'bad_gender'; end if;
  update public.tahfeez_profiles
     set bio = nullif(trim(p_bio), ''),
         city = nullif(trim(p_city), ''),
         country = nullif(trim(p_country), ''),
         plan_period = p_plan,
         free_sessions = p_free,
         price_note = nullif(trim(p_price), ''),
         languages = coalesce(p_languages, '{}'),
         teaches_gender = p_teaches,
         teaches_children = coalesce(p_children, false),
         listed = coalesce(p_listed, true),
         updated_at = now()
   where user_id = auth.uid();
end;
$$;
revoke all on function public.update_teacher_profile(text, text, text, int, text, text[], text, boolean, text, boolean)
  from public, anon;
grant execute on function public.update_teacher_profile(text, text, text, int, text, text[], text, boolean, text, boolean)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Notices: one-line messages to a user, shown once by the app.
create table if not exists public.tahfeez_notices (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  body       text not null,
  created_at timestamptz not null default now(),
  seen       boolean not null default false
);
alter table public.tahfeez_notices enable row level security;
create index if not exists tahfeez_notices_unseen_idx
  on public.tahfeez_notices (user_id) where not seen;
-- Read and written only through the functions below.
revoke all on public.tahfeez_notices from anon, authenticated;

-- Returns the caller's unseen notices and marks them seen in the same call.
create or replace function public.take_notices()
returns setof public.tahfeez_notices language sql security definer set search_path = '' as $$
  update public.tahfeez_notices
     set seen = true
   where user_id = auth.uid() and not seen
  returning *;
$$;
revoke all on function public.take_notices() from public, anon;
grant execute on function public.take_notices() to authenticated;

-- Either side may end an enrolment. When a student withdraws a request that
-- was still pending, the teacher is told; otherwise the row simply goes.
create or replace function public.cancel_enrollment(p_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  e public.tahfeez_enrollments;
  student_name text;
begin
  select * into e from public.tahfeez_enrollments where id = p_id;
  if e.id is null or (e.teacher_id <> auth.uid() and e.student_id <> auth.uid()) then
    raise exception 'not_teacher';
  end if;
  if e.status = 'pending' and e.student_id = auth.uid() then
    select display_name into student_name
      from public.tahfeez_profiles where user_id = e.student_id;
    insert into public.tahfeez_notices (user_id, body)
    values (e.teacher_id, 'cancelled_request:' || coalesce(student_name, ''));
  end if;
  delete from public.tahfeez_members m
   using public.tahfeez_halaqat h
   where h.id = m.halaqa_id and h.teacher_id = e.teacher_id
     and m.student_id = e.student_id;
  delete from public.tahfeez_enrollments where id = p_id;
end;
$$;

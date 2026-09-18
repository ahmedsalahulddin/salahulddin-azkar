-- Enrolment on top of tahfeez.sql: a public directory of approved teachers,
-- each with a personal code; students ask to enrol (by code or from the
-- directory), the teacher accepts, and a weekly or monthly term starts with
-- the teacher's free trial sessions. Payment happens outside the app — the
-- teacher only ticks "paid".
--
-- Run AFTER tahfeez.sql. Safe to run more than once.

-- ---------------------------------------------------------------------------
-- What a teacher shows in the directory.
alter table public.tahfeez_profiles
  add column if not exists teacher_code  text unique,
  add column if not exists bio           text,
  add column if not exists city          text,
  add column if not exists plan_period   text not null default 'month'
                                         check (plan_period in ('week', 'month')),
  add column if not exists free_sessions int  not null default 0
                                         check (free_sessions between 0 and 20),
  add column if not exists price_note    text;

-- One row per teacher–student pair. 'expired' is never stored: an active
-- term whose ends_at has passed reads as expired, and renewing moves the
-- date forward.
create table if not exists public.tahfeez_enrollments (
  id                 uuid primary key default gen_random_uuid(),
  teacher_id         uuid not null references auth.users(id) on delete cascade,
  student_id         uuid not null references auth.users(id) on delete cascade,
  status             text not null default 'pending'
                     check (status in ('pending', 'active', 'rejected')),
  period             text check (period in ('week', 'month')),
  starts_at          date,
  ends_at            date,
  free_sessions_left int  not null default 0,
  paid               boolean not null default false,
  note               text,
  created_at         timestamptz not null default now(),
  decided_at         timestamptz,
  unique (teacher_id, student_id)
);
alter table public.tahfeez_enrollments enable row level security;

drop policy if exists tahfeez_enrollments_select on public.tahfeez_enrollments;
create policy tahfeez_enrollments_select on public.tahfeez_enrollments
  for select to authenticated
  using (teacher_id = auth.uid() or student_id = auth.uid());
grant select on public.tahfeez_enrollments to authenticated;
revoke all on public.tahfeez_enrollments from anon;

-- ---------------------------------------------------------------------------
-- Two people are related once either has asked to work with the other, so
-- a teacher can read the name on a request before accepting it.
create or replace function public.tahfeez_related(other uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.tahfeez_members m
    join public.tahfeez_halaqat h on h.id = m.halaqa_id
    where (h.teacher_id = auth.uid() and m.student_id = other)
       or (h.teacher_id = other and m.student_id = auth.uid())
  ) or exists (
    select 1 from public.tahfeez_enrollments e
    where (e.teacher_id = auth.uid() and e.student_id = other)
       or (e.teacher_id = other and e.student_id = auth.uid())
  )
$$;

-- Every signed-in reader may browse the teachers; everything else as before.
drop policy if exists tahfeez_profiles_select on public.tahfeez_profiles;
create policy tahfeez_profiles_select on public.tahfeez_profiles
  for select to authenticated
  using (
    user_id = auth.uid() or role = 'teacher' or public.is_admin()
      or public.tahfeez_related(user_id)
  );

-- Codes must be unique across circles and teachers alike.
create or replace function public.tahfeez_new_code()
returns text language plpgsql security definer set search_path = '' as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text;
begin
  loop
    code := '';
    for i in 1..6 loop
      code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.tahfeez_halaqat where invite_code = code)
         and not exists (select 1 from public.tahfeez_profiles where teacher_code = code);
  end loop;
  return code;
end;
$$;

-- Approval now also hands the teacher their code.
create or replace function public.decide_teacher_request(p_id uuid, p_approve boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare
  uid uuid;
begin
  if not public.is_admin() then raise exception 'not_admin'; end if;
  update public.tahfeez_teacher_requests
     set status = case when p_approve then 'approved' else 'rejected' end,
         decided_at = now()
   where id = p_id and status = 'pending'
   returning user_id into uid;
  if uid is null then raise exception 'not_pending'; end if;
  if p_approve then
    update public.tahfeez_profiles
       set role = 'teacher',
           teacher_code = coalesce(teacher_code, public.tahfeez_new_code()),
           updated_at = now()
     where user_id = uid;
  end if;
end;
$$;

-- Teachers approved before this file existed get a code too.
update public.tahfeez_profiles
   set teacher_code = public.tahfeez_new_code()
 where role = 'teacher' and teacher_code is null;

-- ---------------------------------------------------------------------------
-- Client entry points.

create or replace function public.update_teacher_profile(
  p_bio text, p_city text, p_plan text, p_free int, p_price text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_teacher() then raise exception 'not_teacher'; end if;
  update public.tahfeez_profiles
     set bio = nullif(trim(p_bio), ''),
         city = nullif(trim(p_city), ''),
         plan_period = p_plan,
         free_sessions = p_free,
         price_note = nullif(trim(p_price), ''),
         updated_at = now()
   where user_id = auth.uid();
end;
$$;

create or replace function public.request_enrollment(p_teacher uuid, p_note text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_teacher = auth.uid() then raise exception 'own_halaqa'; end if;
  if not exists (
    select 1 from public.tahfeez_profiles where user_id = p_teacher and role = 'teacher'
  ) then raise exception 'not_teacher'; end if;
  insert into public.tahfeez_enrollments (teacher_id, student_id, note)
  values (p_teacher, auth.uid(), nullif(trim(p_note), ''))
  on conflict (teacher_id, student_id) do update
    set status = 'pending', note = excluded.note, created_at = now(),
        decided_at = null
    where public.tahfeez_enrollments.status = 'rejected';
end;
$$;

-- Returns the teacher's name so the app can confirm who was asked.
create or replace function public.request_enrollment_by_code(p_code text, p_note text)
returns text language plpgsql security definer set search_path = '' as $$
declare
  tp public.tahfeez_profiles;
begin
  select * into tp from public.tahfeez_profiles
   where teacher_code = upper(trim(p_code)) and role = 'teacher';
  if tp.user_id is null then raise exception 'no_such_code'; end if;
  perform public.request_enrollment(tp.user_id, p_note);
  return tp.display_name;
end;
$$;

-- Accepting starts the term today, on the teacher's current plan.
create or replace function public.decide_enrollment(p_id uuid, p_approve boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare
  e  public.tahfeez_enrollments;
  tp public.tahfeez_profiles;
begin
  select * into e from public.tahfeez_enrollments where id = p_id;
  if e.id is null or e.teacher_id <> auth.uid() then raise exception 'not_teacher'; end if;
  if e.status <> 'pending' then raise exception 'not_pending'; end if;
  select * into tp from public.tahfeez_profiles where user_id = auth.uid();
  if p_approve then
    update public.tahfeez_enrollments
       set status = 'active',
           period = tp.plan_period,
           starts_at = current_date,
           ends_at = current_date + case when tp.plan_period = 'week'
                                         then interval '7 days'
                                         else interval '1 month' end,
           free_sessions_left = tp.free_sessions,
           paid = false,
           decided_at = now()
     where id = p_id;
  else
    update public.tahfeez_enrollments
       set status = 'rejected', decided_at = now()
     where id = p_id;
  end if;
end;
$$;

-- Extends from today or from the current end, whichever is later, and
-- opens a fresh unpaid period.
create or replace function public.renew_enrollment(p_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  e public.tahfeez_enrollments;
begin
  select * into e from public.tahfeez_enrollments where id = p_id;
  if e.id is null or e.teacher_id <> auth.uid() then raise exception 'not_teacher'; end if;
  if e.status <> 'active' then raise exception 'not_pending'; end if;
  update public.tahfeez_enrollments
     set ends_at = greatest(ends_at, current_date)
                   + case when period = 'week' then interval '7 days'
                          else interval '1 month' end,
         paid = false
   where id = p_id;
end;
$$;

create or replace function public.set_enrollment_paid(p_id uuid, p_paid boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.tahfeez_enrollments set paid = p_paid
   where id = p_id and teacher_id = auth.uid();
  if not found then raise exception 'not_teacher'; end if;
end;
$$;

-- Either side may end it. The student also leaves that teacher's circles.
create or replace function public.cancel_enrollment(p_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  e public.tahfeez_enrollments;
begin
  select * into e from public.tahfeez_enrollments where id = p_id;
  if e.id is null or (e.teacher_id <> auth.uid() and e.student_id <> auth.uid()) then
    raise exception 'not_teacher';
  end if;
  delete from public.tahfeez_members m
   using public.tahfeez_halaqat h
   where h.id = m.halaqa_id and h.teacher_id = e.teacher_id
     and m.student_id = e.student_id;
  delete from public.tahfeez_enrollments where id = p_id;
end;
$$;

-- A teacher places an enrolled student into one of their circles.
create or replace function public.assign_to_halaqa(p_halaqa uuid, p_student uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.teaches_halaqa(p_halaqa) then raise exception 'not_teacher'; end if;
  if not exists (
    select 1 from public.tahfeez_enrollments
    where teacher_id = auth.uid() and student_id = p_student and status = 'active'
  ) then raise exception 'not_enrolled'; end if;
  insert into public.tahfeez_members (halaqa_id, student_id)
  values (p_halaqa, p_student)
  on conflict do nothing;
end;
$$;

revoke all on function public.update_teacher_profile(text, text, text, int, text),
  public.request_enrollment(uuid, text), public.request_enrollment_by_code(text, text),
  public.decide_enrollment(uuid, boolean), public.renew_enrollment(uuid),
  public.set_enrollment_paid(uuid, boolean), public.cancel_enrollment(uuid),
  public.assign_to_halaqa(uuid, uuid)
  from public, anon;
grant execute on function public.update_teacher_profile(text, text, text, int, text),
  public.request_enrollment(uuid, text), public.request_enrollment_by_code(text, text),
  public.decide_enrollment(uuid, boolean), public.renew_enrollment(uuid),
  public.set_enrollment_paid(uuid, boolean), public.cancel_enrollment(uuid),
  public.assign_to_halaqa(uuid, uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- A first assessment in a session spends one free trial session, if any
-- remain on the student's active term with that teacher.
create or replace function public.tahfeez_spend_free_session()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  tid uuid;
begin
  select h.teacher_id into tid
    from public.tahfeez_sessions s
    join public.tahfeez_halaqat h on h.id = s.halaqa_id
   where s.id = new.session_id;
  update public.tahfeez_enrollments
     set free_sessions_left = free_sessions_left - 1
   where teacher_id = tid and student_id = new.student_id
     and status = 'active' and free_sessions_left > 0;
  return new;
end;
$$;

drop trigger if exists tahfeez_evaluations_free on public.tahfeez_evaluations;
create trigger tahfeez_evaluations_free
  after insert on public.tahfeez_evaluations
  for each row execute function public.tahfeez_spend_free_session();

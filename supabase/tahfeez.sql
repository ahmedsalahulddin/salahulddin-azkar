-- The memorisation module: teachers, their circles (حلقات), the students in
-- them, a weekly timetable, and what each student was assessed on in a
-- session.
--
-- Everyone signs in with the same OAuth account. A teacher is an ordinary
-- account whose request was approved by an app admin (app_admins from
-- app_sections.sql) — never self-declared. Every write that changes who is
-- what goes through a SECURITY DEFINER function, so the client can only ask.
--
-- Safe to run more than once.

-- ---------------------------------------------------------------------------
-- Profiles: the one place another user may read a name and photo from.
-- auth.users is off-limits to clients, so a teacher could not otherwise see
-- who their students are.
create table if not exists public.tahfeez_profiles (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  photo_url    text,
  role         text not null default 'student'
               check (role in ('student', 'teacher')),
  updated_at   timestamptz not null default now()
);
alter table public.tahfeez_profiles enable row level security;

create table if not exists public.tahfeez_teacher_requests (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  note       text,
  status     text not null default 'pending'
             check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  decided_at timestamptz
);
alter table public.tahfeez_teacher_requests enable row level security;
-- One open request per person.
create unique index if not exists tahfeez_teacher_requests_pending_idx
  on public.tahfeez_teacher_requests (user_id) where status = 'pending';

create table if not exists public.tahfeez_halaqat (
  id          uuid primary key default gen_random_uuid(),
  teacher_id  uuid not null references auth.users(id) on delete cascade,
  name        text not null,
  invite_code text not null unique,
  created_at  timestamptz not null default now()
);
alter table public.tahfeez_halaqat enable row level security;

create table if not exists public.tahfeez_members (
  halaqa_id  uuid not null references public.tahfeez_halaqat(id) on delete cascade,
  student_id uuid not null references auth.users(id) on delete cascade,
  joined_at  timestamptz not null default now(),
  primary key (halaqa_id, student_id)
);
alter table public.tahfeez_members enable row level security;

-- A weekly slot. weekday: 0 = Sunday … 6 = Saturday.
create table if not exists public.tahfeez_sessions (
  id         uuid primary key default gen_random_uuid(),
  halaqa_id  uuid not null references public.tahfeez_halaqat(id) on delete cascade,
  weekday    int  not null check (weekday between 0 and 6),
  start_time time not null,
  end_time   time not null check (end_time > start_time),
  created_at timestamptz not null default now()
);
alter table public.tahfeez_sessions enable row level security;

-- What one student was assessed on in one session on one date. Each of the
-- three points is a JSON object {from_surah, from_ayah, to_surah, to_ayah,
-- grade, note} or null when the teacher chose not to assess it; at least two
-- must be present.
create table if not exists public.tahfeez_evaluations (
  id         uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.tahfeez_sessions(id) on delete cascade,
  student_id uuid not null references auth.users(id) on delete cascade,
  on_date    date not null,
  review     jsonb,
  new_hifz   jsonb,
  tafsir     jsonb,
  updated_at timestamptz not null default now(),
  unique (session_id, student_id, on_date),
  check (
    (review is not null)::int + (new_hifz is not null)::int
      + (tafsir is not null)::int >= 2
  )
);
alter table public.tahfeez_evaluations enable row level security;

-- ---------------------------------------------------------------------------
-- Relationship checks. SECURITY DEFINER so a policy on one table can ask
-- about another without that table's own policies recursing into this one.

create or replace function public.is_teacher()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.tahfeez_profiles
    where user_id = auth.uid() and role = 'teacher'
  )
$$;

create or replace function public.teaches_halaqa(hid uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.tahfeez_halaqat
    where id = hid and teacher_id = auth.uid()
  )
$$;

create or replace function public.member_of_halaqa(hid uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.tahfeez_members
    where halaqa_id = hid and student_id = auth.uid()
  )
$$;

create or replace function public.teaches_session(sid uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.tahfeez_sessions s
    join public.tahfeez_halaqat h on h.id = s.halaqa_id
    where s.id = sid and h.teacher_id = auth.uid()
  )
$$;

create or replace function public.attends_session(sid uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.tahfeez_sessions s
    join public.tahfeez_members m on m.halaqa_id = s.halaqa_id
    where s.id = sid and m.student_id = auth.uid()
  )
$$;

-- True when the caller teaches [other] or is taught by them, in any circle.
create or replace function public.tahfeez_related(other uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.tahfeez_members m
    join public.tahfeez_halaqat h on h.id = m.halaqa_id
    where (h.teacher_id = auth.uid() and m.student_id = other)
       or (h.teacher_id = other and m.student_id = auth.uid())
  )
$$;

revoke all on function public.is_teacher(), public.teaches_halaqa(uuid),
  public.member_of_halaqa(uuid), public.teaches_session(uuid),
  public.attends_session(uuid), public.tahfeez_related(uuid)
  from public, anon;
grant execute on function public.is_teacher(), public.teaches_halaqa(uuid),
  public.member_of_halaqa(uuid), public.teaches_session(uuid),
  public.attends_session(uuid), public.tahfeez_related(uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Policies.

drop policy if exists tahfeez_profiles_select on public.tahfeez_profiles;
create policy tahfeez_profiles_select on public.tahfeez_profiles
  for select to authenticated
  using (
    user_id = auth.uid() or public.is_admin() or public.tahfeez_related(user_id)
  );
-- Writes go through upsert_tahfeez_profile so the role column stays
-- server-owned.

drop policy if exists tahfeez_teacher_requests_select on public.tahfeez_teacher_requests;
create policy tahfeez_teacher_requests_select on public.tahfeez_teacher_requests
  for select to authenticated
  using (user_id = auth.uid() or public.is_admin());

drop policy if exists tahfeez_halaqat_select on public.tahfeez_halaqat;
create policy tahfeez_halaqat_select on public.tahfeez_halaqat
  for select to authenticated
  using (teacher_id = auth.uid() or public.member_of_halaqa(id));
drop policy if exists tahfeez_halaqat_update on public.tahfeez_halaqat;
create policy tahfeez_halaqat_update on public.tahfeez_halaqat
  for update to authenticated
  using (teacher_id = auth.uid()) with check (teacher_id = auth.uid());
drop policy if exists tahfeez_halaqat_delete on public.tahfeez_halaqat;
create policy tahfeez_halaqat_delete on public.tahfeez_halaqat
  for delete to authenticated using (teacher_id = auth.uid());

drop policy if exists tahfeez_members_select on public.tahfeez_members;
create policy tahfeez_members_select on public.tahfeez_members
  for select to authenticated
  using (student_id = auth.uid() or public.teaches_halaqa(halaqa_id));
-- A student may leave; a teacher may remove.
drop policy if exists tahfeez_members_delete on public.tahfeez_members;
create policy tahfeez_members_delete on public.tahfeez_members
  for delete to authenticated
  using (student_id = auth.uid() or public.teaches_halaqa(halaqa_id));

drop policy if exists tahfeez_sessions_select on public.tahfeez_sessions;
create policy tahfeez_sessions_select on public.tahfeez_sessions
  for select to authenticated
  using (public.teaches_halaqa(halaqa_id) or public.member_of_halaqa(halaqa_id));
drop policy if exists tahfeez_sessions_write on public.tahfeez_sessions;
create policy tahfeez_sessions_write on public.tahfeez_sessions
  for all to authenticated
  using (public.teaches_halaqa(halaqa_id))
  with check (public.teaches_halaqa(halaqa_id));

drop policy if exists tahfeez_evaluations_select on public.tahfeez_evaluations;
create policy tahfeez_evaluations_select on public.tahfeez_evaluations
  for select to authenticated
  using (student_id = auth.uid() or public.teaches_session(session_id));
drop policy if exists tahfeez_evaluations_write on public.tahfeez_evaluations;
create policy tahfeez_evaluations_write on public.tahfeez_evaluations
  for all to authenticated
  using (public.teaches_session(session_id))
  with check (public.teaches_session(session_id));

grant select on public.tahfeez_profiles, public.tahfeez_teacher_requests,
  public.tahfeez_halaqat, public.tahfeez_members, public.tahfeez_sessions,
  public.tahfeez_evaluations to authenticated;
grant update, delete on public.tahfeez_halaqat to authenticated;
grant delete on public.tahfeez_members to authenticated;
grant insert, update, delete on public.tahfeez_sessions,
  public.tahfeez_evaluations to authenticated;
revoke all on public.tahfeez_profiles, public.tahfeez_teacher_requests,
  public.tahfeez_halaqat, public.tahfeez_members, public.tahfeez_sessions,
  public.tahfeez_evaluations from anon;

-- ---------------------------------------------------------------------------
-- The eight-a-day ceiling, counted per teacher across all their circles.
-- Enforced here as well as in the app so no client can exceed it.

create or replace function public.tahfeez_limit_sessions()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  tid uuid;
  n   int;
begin
  select teacher_id into tid from public.tahfeez_halaqat where id = new.halaqa_id;
  select count(*) into n
    from public.tahfeez_sessions s
    join public.tahfeez_halaqat h on h.id = s.halaqa_id
   where h.teacher_id = tid
     and s.weekday = new.weekday
     and s.id is distinct from new.id;
  if n >= 8 then
    raise exception 'max_sessions_per_day' using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists tahfeez_sessions_limit on public.tahfeez_sessions;
create trigger tahfeez_sessions_limit
  before insert or update on public.tahfeez_sessions
  for each row execute function public.tahfeez_limit_sessions();

-- ---------------------------------------------------------------------------
-- Client entry points.

-- Called whenever the tab opens signed in, so the name a teacher sees is the
-- one the account currently carries.
create or replace function public.upsert_tahfeez_profile(p_name text, p_photo text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  insert into public.tahfeez_profiles (user_id, display_name, photo_url)
  values (auth.uid(), coalesce(nullif(trim(p_name), ''), 'مستخدم'), p_photo)
  on conflict (user_id) do update
    set display_name = excluded.display_name,
        photo_url    = excluded.photo_url,
        updated_at   = now();
end;
$$;

create or replace function public.request_teacher_role(p_note text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if public.is_teacher() then raise exception 'already_teacher'; end if;
  insert into public.tahfeez_teacher_requests (user_id, note)
  values (auth.uid(), nullif(trim(p_note), ''))
  on conflict do nothing;
end;
$$;

-- Admin only. Approving promotes the profile; either way the request closes.
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
    update public.tahfeez_profiles set role = 'teacher', updated_at = now()
     where user_id = uid;
  end if;
end;
$$;

-- Letters and digits that are not mistaken for one another when read aloud.
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
    exit when not exists (select 1 from public.tahfeez_halaqat where invite_code = code);
  end loop;
  return code;
end;
$$;

-- Returns the new row as JSON, which PostgREST hands the app unchanged.
create or replace function public.create_halaqa(p_name text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  h public.tahfeez_halaqat;
begin
  if not public.is_teacher() then raise exception 'not_teacher'; end if;
  if nullif(trim(p_name), '') is null then raise exception 'empty_name'; end if;
  insert into public.tahfeez_halaqat (teacher_id, name, invite_code)
  values (auth.uid(), trim(p_name), public.tahfeez_new_code())
  returning * into h;
  return to_json(h);
end;
$$;

-- Returns the circle's name so the app can confirm which one was joined.
create or replace function public.join_halaqa(p_code text)
returns text language plpgsql security definer set search_path = '' as $$
declare
  h public.tahfeez_halaqat;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select * into h from public.tahfeez_halaqat
   where invite_code = upper(trim(p_code));
  if h.id is null then raise exception 'no_such_code'; end if;
  if h.teacher_id = auth.uid() then raise exception 'own_halaqa'; end if;
  insert into public.tahfeez_members (halaqa_id, student_id)
  values (h.id, auth.uid())
  on conflict do nothing;
  return h.name;
end;
$$;

create or replace function public.pending_teacher_request_count()
returns int language sql stable security definer set search_path = '' as $$
  select case when public.is_admin()
    then (select count(*)::int from public.tahfeez_teacher_requests where status = 'pending')
    else 0 end
$$;

revoke all on function public.upsert_tahfeez_profile(text, text),
  public.request_teacher_role(text), public.decide_teacher_request(uuid, boolean),
  public.create_halaqa(text), public.join_halaqa(text),
  public.pending_teacher_request_count(), public.tahfeez_new_code()
  from public, anon;
grant execute on function public.upsert_tahfeez_profile(text, text),
  public.request_teacher_role(text), public.decide_teacher_request(uuid, boolean),
  public.create_halaqa(text), public.join_halaqa(text),
  public.pending_teacher_request_count()
  to authenticated;

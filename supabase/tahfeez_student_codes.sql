-- Every Tahfeez profile gets a fixed code (like a teacher's invite code), so
-- a teacher can tell students apart by it even if two share a
-- name. A student's display name is locked while they belong to any circle,
-- so the name a teacher sees in their records stays the one they knew.
-- One call gives a teacher every student they have ever had, with their
-- code, for the "My students" screen. Emails stay private: only admins see
-- them, so the older circle-emails call now hands teachers codes instead.
--
-- Run once in the Supabase SQL editor, after tahfeez.sql,
-- tahfeez_enrollments.sql and tahfeez_display_name.sql.

alter table public.tahfeez_profiles add column if not exists student_code text;
create unique index if not exists tahfeez_profiles_student_code_idx
  on public.tahfeez_profiles (student_code);

-- Letters and digits that are not mistaken for one another when read aloud.
create or replace function public.tahfeez_new_student_code()
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
    exit when not exists (
      select 1 from public.tahfeez_profiles where student_code = code
    );
  end loop;
  return code;
end;
$$;

create or replace function public.tahfeez_profiles_set_code()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.student_code is null then
    new.student_code := public.tahfeez_new_student_code();
  end if;
  return new;
end;
$$;

drop trigger if exists tahfeez_profiles_set_code on public.tahfeez_profiles;
create trigger tahfeez_profiles_set_code
  before insert on public.tahfeez_profiles
  for each row execute function public.tahfeez_profiles_set_code();

-- Existing profiles, one at a time so no two get the same code.
do $$
declare
  r record;
begin
  for r in select user_id from public.tahfeez_profiles where student_code is null loop
    update public.tahfeez_profiles
       set student_code = public.tahfeez_new_student_code()
     where user_id = r.user_id;
  end loop;
end;
$$;

-- A student in any circle keeps their name until they leave it.
create or replace function public.set_tahfeez_display_name(p_name text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if nullif(trim(p_name), '') is null then raise exception 'empty_name'; end if;
  if exists (select 1 from public.tahfeez_members where student_id = auth.uid())
     and exists (select 1 from public.tahfeez_profiles
                 where user_id = auth.uid() and display_name <> trim(p_name)) then
    raise exception 'name_locked';
  end if;
  update public.tahfeez_profiles
     set display_name = trim(p_name), updated_at = now()
   where user_id = auth.uid();
end;
$$;

-- Every student the calling teacher has had (an active enrolment, anyone in
-- one of their circles, or anyone they have assessed), with the code they
-- can be told apart by. No email: that is for admins only.
create or replace function public.tahfeez_teacher_students()
returns table (
  student_id uuid, display_name text, student_code text, photo_url text
) language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_teacher() then raise exception 'not_teacher'; end if;
  return query
    select p.user_id, p.display_name, p.student_code, p.photo_url
    from public.tahfeez_profiles p
    where p.user_id in (
      select e.student_id from public.tahfeez_enrollments e
       where e.teacher_id = auth.uid() and e.status = 'active'
      union
      select m.student_id from public.tahfeez_members m
        join public.tahfeez_halaqat h on h.id = m.halaqa_id
       where h.teacher_id = auth.uid()
      union
      select ev.student_id from public.tahfeez_evaluations ev
        join public.tahfeez_sessions s on s.id = ev.session_id
        join public.tahfeez_halaqat h on h.id = s.halaqa_id
       where h.teacher_id = auth.uid()
    );
end;
$$;

-- The schedule's student search used to fetch emails; it now gets codes, so
-- a teacher never sees a student's email. The return column keeps its old
-- name so app versions already installed keep working.
drop function if exists public.tahfeez_halaqa_emails(uuid);
create function public.tahfeez_halaqa_emails(p_halaqa_id uuid)
returns table (student_id uuid, email text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not exists (
    select 1 from public.tahfeez_halaqat h
    where h.id = p_halaqa_id and h.teacher_id = auth.uid()
  ) then
    raise exception 'not authorized';
  end if;
  return query
    select m.student_id, coalesce(p.student_code, '')
    from public.tahfeez_members m
    left join public.tahfeez_profiles p on p.user_id = m.student_id
    where m.halaqa_id = p_halaqa_id;
end;
$$;
revoke all on function public.tahfeez_halaqa_emails(uuid) from public, anon;
grant execute on function public.tahfeez_halaqa_emails(uuid) to authenticated;

revoke all on function public.tahfeez_new_student_code(),
  public.tahfeez_profiles_set_code(), public.tahfeez_teacher_students()
  from public, anon;
grant execute on function public.tahfeez_teacher_students() to authenticated;

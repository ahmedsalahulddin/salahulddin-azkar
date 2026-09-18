-- Languages and gender on a teacher's card, a student's own gender so the
-- server can refuse a mismatched request, a message thread between the two
-- sides of an enrolment (kept on the server so abuse can be reported and
-- acted on), and blocking by account and by device.
--
-- Run AFTER tahfeez_enrollments.sql. Safe to run more than once.

-- ---------------------------------------------------------------------------
alter table public.tahfeez_profiles
  add column if not exists languages      text[] not null default '{}',
  add column if not exists teaches_gender text not null default 'both'
                                          check (teaches_gender in ('male', 'female', 'both')),
  add column if not exists gender         text check (gender in ('male', 'female')),
  add column if not exists device_id      text,
  add column if not exists blocked        boolean not null default false;

-- Nobody reads this directly: it is consulted by the functions below.
create table if not exists public.tahfeez_blocked_devices (
  device_id  text primary key,
  reason     text,
  blocked_at timestamptz not null default now()
);
alter table public.tahfeez_blocked_devices enable row level security;
revoke all on public.tahfeez_blocked_devices from anon, authenticated;

create or replace function public.tahfeez_is_blocked()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.tahfeez_profiles p
    where p.user_id = auth.uid()
      and (p.blocked or exists (
        select 1 from public.tahfeez_blocked_devices d where d.device_id = p.device_id
      ))
  )
$$;
revoke all on function public.tahfeez_is_blocked() from public, anon;
grant execute on function public.tahfeez_is_blocked() to authenticated;

-- The profile sync now also records the device, and a device that was
-- blocked taints whichever account signs in from it.
drop function if exists public.upsert_tahfeez_profile(text, text);
create or replace function public.upsert_tahfeez_profile(p_name text, p_photo text, p_device text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  created boolean;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  insert into public.tahfeez_profiles (user_id, display_name, photo_url, device_id)
  values (auth.uid(), coalesce(nullif(trim(p_name), ''), 'مستخدم'), p_photo,
          nullif(trim(p_device), ''))
  on conflict (user_id) do update
    set photo_url  = excluded.photo_url,
        device_id  = coalesce(excluded.device_id, public.tahfeez_profiles.device_id),
        updated_at = now()
  returning (xmax = 0) into created;
  if exists (
    select 1 from public.tahfeez_blocked_devices where device_id = nullif(trim(p_device), '')
  ) then
    update public.tahfeez_profiles set blocked = true where user_id = auth.uid();
  end if;
  return json_build_object('created', created, 'blocked', public.tahfeez_is_blocked());
end;
$$;
revoke all on function public.upsert_tahfeez_profile(text, text, text) from public, anon;
grant execute on function public.upsert_tahfeez_profile(text, text, text) to authenticated;

create or replace function public.set_tahfeez_gender(p_gender text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_gender not in ('male', 'female') then raise exception 'bad_gender'; end if;
  update public.tahfeez_profiles set gender = p_gender, updated_at = now()
   where user_id = auth.uid();
end;
$$;
revoke all on function public.set_tahfeez_gender(text) from public, anon;
grant execute on function public.set_tahfeez_gender(text) to authenticated;

drop function if exists public.update_teacher_profile(text, text, text, int, text);
create or replace function public.update_teacher_profile(
  p_bio text, p_city text, p_plan text, p_free int, p_price text,
  p_languages text[], p_teaches text)
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
         updated_at = now()
   where user_id = auth.uid();
end;
$$;
revoke all on function public.update_teacher_profile(text, text, text, int, text, text[], text)
  from public, anon;
grant execute on function public.update_teacher_profile(text, text, text, int, text, text[], text)
  to authenticated;

-- A blocked account may not ask for anything; a mismatched gender is
-- refused here, not merely hidden in the list.
create or replace function public.request_enrollment(p_teacher uuid, p_note text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  sg text;
  tg text;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if public.tahfeez_is_blocked() then raise exception 'blocked'; end if;
  if p_teacher = auth.uid() then raise exception 'own_halaqa'; end if;
  select teaches_gender into tg from public.tahfeez_profiles
   where user_id = p_teacher and role = 'teacher';
  if tg is null then raise exception 'not_teacher'; end if;
  select gender into sg from public.tahfeez_profiles where user_id = auth.uid();
  if tg <> 'both' and (sg is null or sg <> tg) then raise exception 'gender_mismatch'; end if;
  insert into public.tahfeez_enrollments (teacher_id, student_id, note)
  values (p_teacher, auth.uid(), nullif(trim(p_note), ''))
  on conflict (teacher_id, student_id) do update
    set status = 'pending', note = excluded.note, created_at = now(),
        decided_at = null
    where public.tahfeez_enrollments.status = 'rejected';
end;
$$;

create or replace function public.request_teacher_role(p_note text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if public.tahfeez_is_blocked() then raise exception 'blocked'; end if;
  if public.is_teacher() then raise exception 'already_teacher'; end if;
  insert into public.tahfeez_teacher_requests (user_id, note)
  values (auth.uid(), nullif(trim(p_note), ''))
  on conflict do nothing;
end;
$$;

-- ---------------------------------------------------------------------------
-- Messages. One thread per enrolment; either side may report a message from
-- the other, and reported messages become visible to admins.
create table if not exists public.tahfeez_messages (
  id            uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references public.tahfeez_enrollments(id) on delete cascade,
  sender_id     uuid not null references auth.users(id) on delete cascade,
  body          text not null check (length(body) between 1 and 2000),
  created_at    timestamptz not null default now(),
  reported_by   uuid references auth.users(id) on delete set null,
  report_reason text,
  reported_at   timestamptz
);
alter table public.tahfeez_messages enable row level security;
create index if not exists tahfeez_messages_thread_idx
  on public.tahfeez_messages (enrollment_id, created_at);

create or replace function public.party_of_enrollment(eid uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.tahfeez_enrollments
    where id = eid and (teacher_id = auth.uid() or student_id = auth.uid())
  )
$$;
revoke all on function public.party_of_enrollment(uuid) from public, anon;
grant execute on function public.party_of_enrollment(uuid) to authenticated;

drop policy if exists tahfeez_messages_select on public.tahfeez_messages;
create policy tahfeez_messages_select on public.tahfeez_messages
  for select to authenticated
  using (
    public.party_of_enrollment(enrollment_id)
    or (reported_at is not null and public.is_admin())
  );
grant select on public.tahfeez_messages to authenticated;
revoke all on public.tahfeez_messages from anon;

create or replace function public.send_message(p_enrollment uuid, p_body text)
returns json language plpgsql security definer set search_path = '' as $$
declare
  m public.tahfeez_messages;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if public.tahfeez_is_blocked() then raise exception 'blocked'; end if;
  if not public.party_of_enrollment(p_enrollment) then raise exception 'not_party'; end if;
  if nullif(trim(p_body), '') is null then raise exception 'empty_name'; end if;
  insert into public.tahfeez_messages (enrollment_id, sender_id, body)
  values (p_enrollment, auth.uid(), left(trim(p_body), 2000))
  returning * into m;
  return to_json(m);
end;
$$;

create or replace function public.report_message(p_id uuid, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  m public.tahfeez_messages;
begin
  select * into m from public.tahfeez_messages where id = p_id;
  if m.id is null or not public.party_of_enrollment(m.enrollment_id) then
    raise exception 'not_party';
  end if;
  if m.sender_id = auth.uid() then raise exception 'not_party'; end if;
  update public.tahfeez_messages
     set reported_by = auth.uid(), report_reason = nullif(trim(p_reason), ''),
         reported_at = coalesce(reported_at, now())
   where id = p_id;
end;
$$;

create or replace function public.reported_message_count()
returns int language sql stable security definer set search_path = '' as $$
  select case when public.is_admin()
    then (select count(*)::int from public.tahfeez_messages where reported_at is not null)
    else 0 end
$$;

-- Admin only. Blocks the account and the device it last signed in from,
-- and closes any open requests it made.
create or replace function public.block_user(p_user uuid, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  dev text;
begin
  if not public.is_admin() then raise exception 'not_admin'; end if;
  update public.tahfeez_profiles set blocked = true, updated_at = now()
   where user_id = p_user
   returning device_id into dev;
  if dev is not null then
    insert into public.tahfeez_blocked_devices (device_id, reason)
    values (dev, nullif(trim(p_reason), ''))
    on conflict do nothing;
  end if;
  update public.tahfeez_enrollments set status = 'rejected', decided_at = now()
   where student_id = p_user and status = 'pending';
  update public.tahfeez_teacher_requests set status = 'rejected', decided_at = now()
   where user_id = p_user and status = 'pending';
end;
$$;

create or replace function public.unblock_user(p_user uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  dev text;
begin
  if not public.is_admin() then raise exception 'not_admin'; end if;
  update public.tahfeez_profiles set blocked = false, updated_at = now()
   where user_id = p_user
   returning device_id into dev;
  if dev is not null then
    delete from public.tahfeez_blocked_devices where device_id = dev;
  end if;
end;
$$;

-- Lets the admin clear a report without blocking.
create or replace function public.dismiss_report(p_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'not_admin'; end if;
  update public.tahfeez_messages
     set reported_by = null, report_reason = null, reported_at = null
   where id = p_id;
end;
$$;

revoke all on function public.send_message(uuid, text), public.report_message(uuid, text),
  public.reported_message_count(), public.block_user(uuid, text),
  public.unblock_user(uuid), public.dismiss_report(uuid)
  from public, anon;
grant execute on function public.send_message(uuid, text), public.report_message(uuid, text),
  public.reported_message_count(), public.block_user(uuid, text),
  public.unblock_user(uuid), public.dismiss_report(uuid)
  to authenticated;

-- Live delivery inside an open thread. Row-level security still applies
-- to what each subscriber receives.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename = 'tahfeez_messages'
  ) then
    alter publication supabase_realtime add table public.tahfeez_messages;
  end if;
end $$;

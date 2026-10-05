-- A teacher's free hours, shown to students in the directory, and a switch
-- to show or hide themselves there without touching the rest of the profile.
--
-- availability is a JSON array of {"d": weekday 0–6 (Sunday = 0), "f": from,
-- "t": to}, times in minutes after midnight.
--
-- Run once in the Supabase SQL editor, after tahfeez.sql.

alter table public.tahfeez_profiles
  add column if not exists availability jsonb not null default '[]'::jsonb;

create or replace function public.set_teacher_availability(p_slots jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare
  s jsonb;
begin
  if not public.is_teacher() then raise exception 'not_teacher'; end if;
  if jsonb_typeof(p_slots) <> 'array' or jsonb_array_length(p_slots) > 28 then
    raise exception 'bad_availability';
  end if;
  for s in select * from jsonb_array_elements(p_slots) loop
    if not ((s->>'d')::int between 0 and 6
            and (s->>'f')::int between 0 and 1439
            and (s->>'t')::int between 1 and 1440
            and (s->>'f')::int < (s->>'t')::int) then
      raise exception 'bad_availability';
    end if;
  end loop;
  update public.tahfeez_profiles
     set availability = p_slots, updated_at = now()
   where user_id = auth.uid();
end;
$$;

create or replace function public.set_teacher_listed(p_listed boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_teacher() then raise exception 'not_teacher'; end if;
  update public.tahfeez_profiles
     set listed = coalesce(p_listed, true), updated_at = now()
   where user_id = auth.uid();
end;
$$;

revoke all on function public.set_teacher_availability(jsonb) from public, anon;
revoke all on function public.set_teacher_listed(boolean) from public, anon;
grant execute on function public.set_teacher_availability(jsonb) to authenticated;
grant execute on function public.set_teacher_listed(boolean) to authenticated;

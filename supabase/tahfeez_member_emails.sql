-- Lets a teacher read the email of a student in one of their own circles —
-- used by the schedule's student filter/search, where a display name alone
-- is not enough to find one student among many. auth.users is never
-- directly queryable from the client, so this is a SECURITY DEFINER
-- function that checks the caller actually teaches the circle before
-- reading it, rather than relaxing a table-level policy.
--
-- Run AFTER tahfeez.sql. Safe to run more than once.

create or replace function public.tahfeez_halaqa_emails(p_halaqa_id uuid)
returns table (student_id uuid, email text)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.tahfeez_halaqat h
    where h.id = p_halaqa_id and h.teacher_id = auth.uid()
  ) then
    raise exception 'not authorized';
  end if;

  return query
    select m.student_id, u.email::text
    from public.tahfeez_members m
    join auth.users u on u.id = m.student_id
    where m.halaqa_id = p_halaqa_id;
end;
$$;

grant execute on function public.tahfeez_halaqa_emails(uuid) to authenticated;

-- Tell the reader how their teacher request went. Deciding a request now
-- leaves them a notice (tahfeez_notices, from tahfeez_directory.sql), which
-- the app shows once the next time the Tahfeez tab loads. The bodies are
-- readable sentences so older app versions, which print a notice as-is,
-- still say something sensible; newer ones recognise them and show a dialog
-- (TahfeezService.teacherApprovedNotice / teacherRejectedNotice).
--
-- Run once in the Supabase SQL editor, after tahfeez.sql and
-- tahfeez_directory.sql.

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
  insert into public.tahfeez_notices (user_id, body)
  values (uid, case when p_approve then 'تم قبولك كمحفّظ ✅' else 'لم يُقبل طلبك كمحفّظ هذه المرة — تقدر تبعت طلب جديد' end);
end;
$$;

-- Requests already decided this past week never got a notice; give them one,
-- unless the person has since asked again.
insert into public.tahfeez_notices (user_id, body)
select r.user_id,
       case when r.status = 'approved' then 'تم قبولك كمحفّظ ✅' else 'لم يُقبل طلبك كمحفّظ هذه المرة — تقدر تبعت طلب جديد' end
from public.tahfeez_teacher_requests r
where r.status in ('approved', 'rejected')
  and r.decided_at > now() - interval '7 days'
  and not exists (
    select 1 from public.tahfeez_teacher_requests newer
    where newer.user_id = r.user_id and newer.created_at > r.created_at
  )
  and not exists (
    select 1 from public.tahfeez_notices n
    where n.user_id = r.user_id and n.body in ('تم قبولك كمحفّظ ✅', 'لم يُقبل طلبك كمحفّظ هذه المرة — تقدر تبعت طلب جديد')
  );

-- Messages between readers and the admins: a reader opens a request
-- (an edit, a teacher question, a problem, a suggestion…) and both sides
-- reply in one thread. The admin marks each one solved or not, and can star
-- any to come back to. Replaces translation_feedback, whose notes are
-- copied in below; "Contact us" and the language notice now write here.
--
-- Text only, so it stays small (100,000 messages ≈ 30 MB).
--
-- Run once in the Supabase SQL editor, after app_sections.sql (is_admin).

create table if not exists public.support_threads (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid references auth.users(id) on delete cascade,
  category        text not null default 'other'
                  check (category in ('edit', 'teacher', 'problem',
                                      'suggestion', 'translation', 'contact', 'other')),
  app_lang        text,
  status          text not null default 'open' check (status in ('open', 'resolved')),
  starred         boolean not null default false,
  user_unread     boolean not null default false,
  admin_unread    boolean not null default true,
  created_at      timestamptz not null default now(),
  last_message_at timestamptz not null default now()
);
create index if not exists support_threads_user_idx on public.support_threads (user_id);
create index if not exists support_threads_admin_idx
  on public.support_threads (status, last_message_at desc);

create table if not exists public.support_messages (
  id         bigint generated always as identity primary key,
  thread_id  uuid not null references public.support_threads(id) on delete cascade,
  sender_id  uuid references auth.users(id) on delete set null,
  from_admin boolean not null default false,
  body       text not null check (length(trim(body)) > 0 and length(body) <= 4000),
  created_at timestamptz not null default now()
);
create index if not exists support_messages_thread_idx
  on public.support_messages (thread_id, created_at);

alter table public.support_threads enable row level security;
alter table public.support_messages enable row level security;

-- Readers see their own threads; admins see all. Writes go through the
-- functions below only.
drop policy if exists support_threads_select on public.support_threads;
create policy support_threads_select on public.support_threads
  for select to authenticated
  using (user_id = auth.uid() or public.is_admin());

drop policy if exists support_messages_select on public.support_messages;
create policy support_messages_select on public.support_messages
  for select to authenticated
  using (exists (
    select 1 from public.support_threads t
    where t.id = thread_id and (t.user_id = auth.uid() or public.is_admin())
  ));

revoke all on public.support_threads, public.support_messages from anon, authenticated;
grant select on public.support_threads, public.support_messages to authenticated;

-- Opens a thread with its first message. Guests may write too (no reply can
-- reach them in the app, so the contact form asks for an email in the text).
create or replace function public.support_open(p_category text, p_body text, p_lang text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  tid uuid;
begin
  if nullif(trim(p_body), '') is null then raise exception 'empty'; end if;
  insert into public.support_threads (user_id, category, app_lang)
  values (auth.uid(),
          case when p_category in ('edit', 'teacher', 'problem', 'suggestion',
                                   'translation', 'contact', 'other')
               then p_category else 'other' end,
          nullif(trim(p_lang), ''))
  returning id into tid;
  insert into public.support_messages (thread_id, sender_id, from_admin, body)
  values (tid, auth.uid(), false, left(trim(p_body), 4000));
  return tid;
end;
$$;

-- A reply from the thread's owner or an admin. A reader replying to a
-- solved request reopens it.
create or replace function public.support_reply(p_thread uuid, p_body text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  owner uuid;
  admin boolean := public.is_admin();
begin
  select user_id into owner from public.support_threads where id = p_thread;
  if not found then raise exception 'not_found'; end if;
  if not admin and (owner is null or owner <> auth.uid()) then
    raise exception 'not_allowed';
  end if;
  if nullif(trim(p_body), '') is null then raise exception 'empty'; end if;
  insert into public.support_messages (thread_id, sender_id, from_admin, body)
  values (p_thread, auth.uid(), admin and owner is distinct from auth.uid(),
          left(trim(p_body), 4000));
  if admin and owner is distinct from auth.uid() then
    update public.support_threads
       set last_message_at = now(), user_unread = true
     where id = p_thread;
  else
    update public.support_threads
       set last_message_at = now(), admin_unread = true, status = 'open'
     where id = p_thread;
  end if;
end;
$$;

create or replace function public.support_set_status(p_thread uuid, p_resolved boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'not_admin'; end if;
  update public.support_threads
     set status = case when p_resolved then 'resolved' else 'open' end
   where id = p_thread;
end;
$$;

create or replace function public.support_set_starred(p_thread uuid, p_starred boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'not_admin'; end if;
  update public.support_threads set starred = coalesce(p_starred, false)
   where id = p_thread;
end;
$$;

-- Marks a thread read for whoever is looking: the owner, or the admins.
create or replace function public.support_mark_read(p_thread uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.support_threads set user_unread = false
   where id = p_thread and user_id = auth.uid();
  if public.is_admin() then
    update public.support_threads set admin_unread = false
     where id = p_thread and user_id is distinct from auth.uid();
  end if;
end;
$$;

-- The admin inbox: every thread with who sent it and its latest message.
create or replace function public.support_admin_threads()
returns table (
  id uuid, user_id uuid, email text, name text, category text, app_lang text,
  status text, starred boolean, admin_unread boolean, created_at timestamptz,
  last_message_at timestamptz, last_body text, message_count int
) language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'not_admin'; end if;
  return query
    select t.id, t.user_id, u.email::text,
           coalesce(p.display_name, u.raw_user_meta_data->>'full_name',
                    u.raw_user_meta_data->>'name')::text,
           t.category, t.app_lang, t.status, t.starred, t.admin_unread,
           t.created_at, t.last_message_at,
           (select m.body from public.support_messages m
             where m.thread_id = t.id order by m.created_at desc limit 1),
           (select count(*)::int from public.support_messages m where m.thread_id = t.id)
    from public.support_threads t
    left join auth.users u on u.id = t.user_id
    left join public.tahfeez_profiles p on p.user_id = t.user_id
    order by t.last_message_at desc;
end;
$$;

revoke all on function public.support_open(text, text, text),
  public.support_reply(uuid, text), public.support_set_status(uuid, boolean),
  public.support_set_starred(uuid, boolean), public.support_mark_read(uuid),
  public.support_admin_threads()
  from public;
grant execute on function public.support_open(text, text, text) to anon, authenticated;
grant execute on function public.support_reply(uuid, text),
  public.support_set_status(uuid, boolean), public.support_set_starred(uuid, boolean),
  public.support_mark_read(uuid), public.support_admin_threads()
  to authenticated;

-- Bring the old translation notes and contact messages across once.
do $$
declare
  r record;
  tid uuid;
begin
  if exists (select 1 from information_schema.tables
             where table_schema = 'public' and table_name = 'translation_feedback')
     and not exists (select 1 from public.support_threads) then
    for r in select * from public.translation_feedback order by created_at loop
      insert into public.support_threads
        (user_id, category, app_lang, admin_unread, created_at, last_message_at)
      values (r.user_id,
              case when r.message like '✉️%' then 'contact' else 'translation' end,
              r.app_lang, not r.is_read, r.created_at, r.created_at)
      returning id into tid;
      insert into public.support_messages (thread_id, sender_id, from_admin, body, created_at)
      values (tid, r.user_id, false,
              coalesce(nullif(trim(regexp_replace(r.message, '^✉️\s*', '')), ''), r.message),
              r.created_at);
    end loop;
  end if;
end;
$$;

-- A reader can leave the admin a note when they see untranslated content
-- after switching the app's language — the dialog that offers this fires
-- from lib/screens/home_screen.dart every time the language changes.
-- Anyone (guest or signed in) can write one; only the admin can read them.

create table if not exists public.translation_feedback (
  id         bigint generated always as identity primary key,
  user_id    uuid references auth.users(id) on delete set null,
  app_lang   text not null,
  message    text not null,
  is_read    boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.translation_feedback enable row level security;

drop policy if exists translation_feedback_insert on public.translation_feedback;
create policy translation_feedback_insert on public.translation_feedback
  for insert to authenticated, anon
  with check (length(trim(message)) > 0 and length(message) <= 2000);

drop policy if exists translation_feedback_admin on public.translation_feedback;
create policy translation_feedback_admin on public.translation_feedback
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

grant insert on public.translation_feedback to authenticated, anon;
grant select, update, delete on public.translation_feedback to authenticated;

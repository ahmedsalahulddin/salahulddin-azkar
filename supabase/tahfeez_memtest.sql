-- Saved results for the Memory Test drill (lib/screens/memorisation_test_screen.dart),
-- so a run's score survives leaving the screen and — when the reader and a
-- teacher are related — becomes part of the same transcript the teacher's
-- own evaluations already build, via public.tahfeez_related() from
-- tahfeez_enrollments.sql.
--
-- Unlike tahfeez_evaluations (teacher-graded, teacher-written only), this is
-- self-administered: the student both takes the test and writes their own
-- result, so the insert policy checks student_id = auth.uid() rather than
-- routing through a teacher-only helper like teaches_session().
--
-- Run AFTER tahfeez_enrollments.sql (needs tahfeez_related()). Safe to run
-- more than once.

create table if not exists public.tahfeez_memtest_results (
  id             uuid primary key default gen_random_uuid(),
  student_id     uuid not null references auth.users(id) on delete cascade,
  surah_number   int  not null check (surah_number between 1 and 114),
  surah_name     text not null,
  mode           text not null check (mode in ('complete', 'order', 'missing', 'next')),
  question_count int  not null check (question_count > 0),
  correct_count  int  not null check (correct_count >= 0 and correct_count <= question_count),
  score_percent  int  not null check (score_percent between 0 and 100),
  created_at     timestamptz not null default now()
);
alter table public.tahfeez_memtest_results enable row level security;

drop policy if exists tahfeez_memtest_results_select on public.tahfeez_memtest_results;
create policy tahfeez_memtest_results_select on public.tahfeez_memtest_results
  for select to authenticated
  using (student_id = auth.uid() or public.tahfeez_related(student_id));

drop policy if exists tahfeez_memtest_results_insert on public.tahfeez_memtest_results;
create policy tahfeez_memtest_results_insert on public.tahfeez_memtest_results
  for insert to authenticated
  with check (student_id = auth.uid());

grant select, insert on public.tahfeez_memtest_results to authenticated;
revoke all on public.tahfeez_memtest_results from anon;

create index if not exists tahfeez_memtest_results_student_idx
  on public.tahfeez_memtest_results (student_id, created_at desc);

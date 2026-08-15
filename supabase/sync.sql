-- Reading state that follows the reader between devices: bookmarks, notes,
-- favourite adhkar, and where they had reached in the Mushaf.
--
-- Everything here is private. The policies below are the only thing standing
-- between one reader's notes and another's, so they are written to be read: a
-- row belongs to auth.uid(), and no policy grants anything wider.
--
-- Safe to run more than once.

create table if not exists reader_state (
  user_id    uuid        not null references auth.users(id) on delete cascade,
  -- 'bookmark' | 'favourite' | 'position'. Kept as one table because these
  -- differ only in what the key means, and three tables with identical
  -- policies is three chances to get the policies wrong.
  kind       text        not null,
  -- Bookmarks: 'surah:ayah'. Favourites: the dhikr id. Position: 'mushaf'.
  key        text        not null,
  value      jsonb       not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (user_id, kind, key)
);

alter table reader_state enable row level security;

-- Four policies, one per verb, each saying the same thing: your own rows only.
drop policy if exists reader_state_select on reader_state;
create policy reader_state_select on reader_state
  for select using (auth.uid() = user_id);

drop policy if exists reader_state_insert on reader_state;
create policy reader_state_insert on reader_state
  for insert with check (auth.uid() = user_id);

drop policy if exists reader_state_update on reader_state;
create policy reader_state_update on reader_state
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists reader_state_delete on reader_state;
create policy reader_state_delete on reader_state
  for delete using (auth.uid() = user_id);

-- The one query the app makes: everything of mine, newest first.
create index if not exists reader_state_user_idx
  on reader_state (user_id, kind, updated_at desc);

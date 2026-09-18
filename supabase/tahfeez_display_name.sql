-- Lets a reader set a name of their own for the memorisation module,
-- instead of the one their Google account carries — someone tutoring or
-- being tutored may not want to share their real name with a stranger.
--
-- Run AFTER tahfeez.sql. Safe to run more than once.

-- Previously every tab-open re-synced display_name from Google, which would
-- silently overwrite a custom name. From now on the sync only ever sets the
-- name on first insert; an explicit edit (below) is the only way it changes
-- after that. Returns whether this call just created the row, so the app
-- can offer to name it right away instead of defaulting silently.
create or replace function public.upsert_tahfeez_profile(p_name text, p_photo text)
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  created boolean;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  insert into public.tahfeez_profiles (user_id, display_name, photo_url)
  values (auth.uid(), coalesce(nullif(trim(p_name), ''), 'مستخدم'), p_photo)
  on conflict (user_id) do update
    set photo_url  = excluded.photo_url,
        updated_at = now()
  returning (xmax = 0) into created;
  return created;
end;
$$;

create or replace function public.set_tahfeez_display_name(p_name text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if nullif(trim(p_name), '') is null then raise exception 'empty_name'; end if;
  update public.tahfeez_profiles
     set display_name = trim(p_name), updated_at = now()
   where user_id = auth.uid();
end;
$$;

revoke all on function public.set_tahfeez_display_name(text) from public, anon;
grant execute on function public.set_tahfeez_display_name(text) to authenticated;

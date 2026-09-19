-- Lets any reader (not just a teacher editing their listing) set their own
-- country from the merged profile card, the same way set_tahfeez_gender
-- already lets them set gender. The `country` column itself was added by
-- tahfeez_directory.sql; this only adds the setter.
--
-- Run AFTER tahfeez_directory.sql. Safe to run more than once.

create or replace function public.set_tahfeez_country(p_country text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  update public.tahfeez_profiles set country = nullif(trim(p_country), ''), updated_at = now()
   where user_id = auth.uid();
end;
$$;
revoke all on function public.set_tahfeez_country(text) from public, anon;
grant execute on function public.set_tahfeez_country(text) to authenticated;

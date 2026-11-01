-- Administratorsko uklanjanje člana iz aplikacije ČARAPANI
-- Funkcija briše profil i Auth nalog. Ne može obrisati samog administratora koji je prijavljen,
-- niti druge administratorske naloge.

create or replace function public.admin_delete_member(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'Morate biti prijavljeni.';
  end if;

  if not exists (
    select 1 from public.profiles
    where id = auth.uid() and is_admin = true
  ) then
    raise exception 'Samo administrator može uklanjati članove.';
  end if;

  if p_user_id = auth.uid() then
    raise exception 'Ne možete obrisati sopstveni nalog.';
  end if;

  if exists (
    select 1 from public.profiles
    where id = p_user_id and is_admin = true
  ) then
    raise exception 'Administratorski nalozi se ne mogu obrisati ovim postupkom.';
  end if;

  delete from public.profiles where id = p_user_id;
  delete from auth.users where id = p_user_id;

  if not found then
    raise exception 'Nalog nije pronađen.';
  end if;
end;
$$;

revoke all on function public.admin_delete_member(uuid) from public;
grant execute on function public.admin_delete_member(uuid) to authenticated;

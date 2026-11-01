-- Činovi članova kluba ČARAPANI
-- Pokreni ovaj SQL jednom u Supabase SQL Editor-u.

alter table public.profiles
  add column if not exists club_rank text not null default 'Član kluba';

alter table public.profiles
  drop constraint if exists profiles_club_rank_check;

alter table public.profiles
  add constraint profiles_club_rank_check
  check (club_rank in ('Član kluba', 'Gost', 'Prijatelj kluba'));

create or replace function public.is_club_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and is_admin = true
  );
$$;

drop policy if exists "Admins can update member club ranks" on public.profiles;

create policy "Admins can update member club ranks"
on public.profiles
for update
to authenticated
using (public.is_club_admin())
with check (public.is_club_admin());

grant execute on function public.is_club_admin() to authenticated;

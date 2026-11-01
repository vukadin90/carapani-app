-- Posebna ovlašćenja za objavljivanje klupskih događaja i obaveštenja.
-- Ne dodeljuje administratorski status i ne daje pravo upravljanja chat-om.

create table if not exists public.content_publishers (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  can_publish_events boolean not null default false,
  can_publish_announcements boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.content_publishers enable row level security;
grant select on public.content_publishers to authenticated;

drop policy if exists "Members can read own content publisher permissions" on public.content_publishers;
create policy "Members can read own content publisher permissions"
on public.content_publishers for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "Admins can manage content publisher permissions" on public.content_publishers;
create policy "Admins can manage content publisher permissions"
on public.content_publishers for all
to authenticated
using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
)
with check (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
);

drop policy if exists "Content publishers can insert club events" on public.club_events;
create policy "Content publishers can insert club events"
on public.club_events for insert
to authenticated
with check (
  created_by = auth.uid()
  and exists (select 1 from public.profiles p where p.id = auth.uid() and p.approved = true)
  and exists (
    select 1 from public.content_publishers cp
    where cp.user_id = auth.uid() and cp.can_publish_events = true
  )
);

drop policy if exists "Content publishers can insert club announcements" on public.club_announcements;
create policy "Content publishers can insert club announcements"
on public.club_announcements for insert
to authenticated
with check (
  created_by = auth.uid()
  and exists (select 1 from public.profiles p where p.id = auth.uid() and p.approved = true)
  and exists (
    select 1 from public.content_publishers cp
    where cp.user_id = auth.uid() and cp.can_publish_announcements = true
  )
);

grant insert on public.club_events to authenticated;
grant insert on public.club_announcements to authenticated;

-- Dodela samo Goranu, prema e-mail adresi njegovog naloga.
-- Ako e-mail nije povezan sa odobrenim profilom, proveri adresu/nalog pre ponovnog pokretanja.
insert into public.content_publishers (user_id, can_publish_events, can_publish_announcements)
select p.id, true, true
from auth.users u
join public.profiles p on p.id = u.id
where lower(u.email) = lower('motoklubcarapani@gmail.com')
  and p.approved = true
on conflict (user_id) do update
set can_publish_events = true,
    can_publish_announcements = true;

do $$
begin
  if not exists (
    select 1
    from public.content_publishers cp
    join auth.users u on u.id = cp.user_id
    where lower(u.email) = lower('motoklubcarapani@gmail.com')
      and cp.can_publish_events = true
      and cp.can_publish_announcements = true
  ) then
    raise exception 'Nalog sa e-mail adresom motoklubcarapani@gmail.com nije pronađen ili profil nije odobren. Proveri da li je Goran registrovan i odobren.';
  end if;
end $$;

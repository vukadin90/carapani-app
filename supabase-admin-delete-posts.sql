-- Omogući administratoru da briše sve klupske događaje i obaveštenja,
-- bez obzira na to ko ih je objavio.

drop policy if exists "Admins can delete any club event" on public.club_events;
create policy "Admins can delete any club event"
on public.club_events
for delete
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.is_admin = true
  )
);

drop policy if exists "Admins can delete any club announcement" on public.club_announcements;
create policy "Admins can delete any club announcement"
on public.club_announcements
for delete
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.is_admin = true
  )
);

grant delete on public.club_events to authenticated;
grant delete on public.club_announcements to authenticated;

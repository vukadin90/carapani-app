-- Dozvoli autoru objave i administratoru da uređuju moto ture i događaje.

drop policy if exists "Authors and admins can update rides" on public.rides;
create policy "Authors and admins can update rides"
on public.rides
for update
to authenticated
using (
  user_id = auth.uid()
  or exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
)
with check (
  user_id = auth.uid()
  or exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
);

drop policy if exists "Authors and admins can update club events" on public.club_events;
create policy "Authors and admins can update club events"
on public.club_events
for update
to authenticated
using (
  created_by = auth.uid()
  or exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
)
with check (
  created_by = auth.uid()
  or exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
);

grant update on public.rides to authenticated;
grant update on public.club_events to authenticated;

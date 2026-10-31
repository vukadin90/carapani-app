-- Omogući administratorima kluba da brišu sve moto ture,
-- uključujući ture koje su objavili drugi članovi.
drop policy if exists "Admins can delete any ride" on public.rides;

create policy "Admins can delete any ride"
on public.rides
for delete
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.is_admin = true
  )
);

-- Dozvoli članu da obriše samo svoju moto vožnju.
-- Postojeća administratorska DELETE politika ostaje aktivna.
drop policy if exists "Members can delete own rides" on public.rides;

create policy "Members can delete own rides"
on public.rides
for delete
to authenticated
using (
  user_id = auth.uid()
);

-- Administratorska kontrola članskog chata:
-- brisanje svih poruka i zabrana/dozvola pisanja pojedinim članovima.

create table if not exists public.chat_restrictions (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  blocked_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

alter table public.chat_restrictions enable row level security;
grant select, insert, update, delete on public.chat_restrictions to authenticated;
grant delete on public.chat_messages to authenticated;

drop policy if exists "Members can see own chat restriction" on public.chat_restrictions;
create policy "Members can see own chat restriction"
on public.chat_restrictions for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "Admins can manage chat restrictions" on public.chat_restrictions;
create policy "Admins can manage chat restrictions"
on public.chat_restrictions for all
to authenticated
using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
)
with check (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
);

drop policy if exists "Approved members can send chat" on public.chat_messages;
create policy "Approved members can send chat"
on public.chat_messages for insert
to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.approved = true
  )
  and not exists (
    select 1 from public.chat_restrictions r
    where r.user_id = auth.uid()
  )
);

drop policy if exists "Admins can delete any chat message" on public.chat_messages;
create policy "Admins can delete any chat message"
on public.chat_messages for delete
to authenticated
using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
);

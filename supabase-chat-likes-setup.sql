-- Lajkovanje poruka u chatu Moto kluba ČARAPANI
create table if not exists public.chat_message_likes (
  message_id uuid not null references public.chat_messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

alter table public.chat_message_likes enable row level security;

grant select, insert, delete on public.chat_message_likes to authenticated;

drop policy if exists "Approved members can view chat likes" on public.chat_message_likes;
create policy "Approved members can view chat likes"
on public.chat_message_likes for select
to authenticated
using (
  exists (select 1 from public.profiles p
          where p.id = auth.uid() and p.approved = true)
);

drop policy if exists "Approved members can like chat messages" on public.chat_message_likes;
create policy "Approved members can like chat messages"
on public.chat_message_likes for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (select 1 from public.profiles p
              where p.id = auth.uid() and p.approved = true)
);

drop policy if exists "Members can remove their own chat likes" on public.chat_message_likes;
create policy "Members can remove their own chat likes"
on public.chat_message_likes for delete
to authenticated
using (user_id = auth.uid());

-- Omogućava da se broj lajkova ažurira uživo u otvorenom chatu.
do $$
begin
  alter publication supabase_realtime add table public.chat_message_likes;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

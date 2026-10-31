-- Moto klub ČARAPANI: podaci o motorima članova
create table if not exists public.member_motorcycles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  bike_name text,
  brand text,
  model text,
  cc integer,
  horsepower integer,
  description text,
  photo_url text,
  updated_at timestamptz not null default now()
);

alter table public.member_motorcycles enable row level security;

drop policy if exists "Approved members can view motorcycle profiles" on public.member_motorcycles;
create policy "Approved members can view motorcycle profiles"
on public.member_motorcycles for select to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.approved = true
  )
);

drop policy if exists "Members manage their own motorcycle profile" on public.member_motorcycles;
create policy "Members manage their own motorcycle profile"
on public.member_motorcycles for all to authenticated
using (user_id = auth.uid())
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.approved = true
  )
);

insert into storage.buckets (id, name, public)
values ('motorcycle-photos', 'motorcycle-photos', true)
on conflict (id) do update set public = true;

drop policy if exists "Motorcycle photos are publicly viewable" on storage.objects;
create policy "Motorcycle photos are publicly viewable"
on storage.objects for select
using (bucket_id = 'motorcycle-photos');

drop policy if exists "Members upload their own motorcycle photo" on storage.objects;
create policy "Members upload their own motorcycle photo"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'motorcycle-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Members update their own motorcycle photo" on storage.objects;
create policy "Members update their own motorcycle photo"
on storage.objects for update to authenticated
using (
  bucket_id = 'motorcycle-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'motorcycle-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Members delete their own motorcycle photo" on storage.objects;
create policy "Members delete their own motorcycle photo"
on storage.objects for delete to authenticated
using (
  bucket_id = 'motorcycle-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

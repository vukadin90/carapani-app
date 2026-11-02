-- Sprečava da ista registracija pošalje više push obaveštenja administratoru.
create table if not exists public.registration_push_log (
  user_id uuid primary key,
  created_at timestamptz not null default now()
);

alter table public.registration_push_log enable row level security;
revoke all on table public.registration_push_log from anon, authenticated;
grant all on table public.registration_push_log to service_role;

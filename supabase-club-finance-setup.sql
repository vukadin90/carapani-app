-- BLAGAJNA ČARAPANI
-- Initial monthly fee: 1,000 RSD; annual calendar-year payment: 12,000 RSD.
-- All approved members can read financial data; only club admins can write until a cashier role is added.

create table if not exists public.club_finance_settings (
  id boolean primary key default true check (id = true),
  monthly_fee numeric(12,2) not null default 1000 check (monthly_fee > 0),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);
insert into public.club_finance_settings (id, monthly_fee)
values (true, 1000)
on conflict (id) do nothing;

create table if not exists public.club_finance_transactions (
  id uuid primary key default gen_random_uuid(),
  transaction_type text not null check (transaction_type in ('membership','donation','other_income','expense')),
  amount numeric(12,2) not null check (amount > 0),
  transaction_date date not null default current_date,
  description text not null default '',
  category text,
  member_id uuid references public.profiles(id) on delete restrict,
  donor_name text,
  is_anonymous boolean not null default false,
  membership_year integer,
  membership_month smallint,
  membership_period text,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint club_finance_membership_fields check (
    (transaction_type = 'membership' and member_id is not null and membership_year between 2000 and 2200
      and ((membership_period = 'monthly' and membership_month between 1 and 12 and amount = 1000)
        or (membership_period = 'annual' and membership_month is null and amount = 12000)))
    or (transaction_type <> 'membership' and member_id is null and membership_year is null and membership_month is null and membership_period is null)
  ),
  constraint club_finance_donor_only_for_donations check (
    transaction_type = 'donation' or (donor_name is null and is_anonymous = false)
  )
);
create unique index if not exists club_finance_monthly_membership_unique on public.club_finance_transactions(member_id,membership_year,membership_month) where transaction_type='membership' and membership_period='monthly';
create unique index if not exists club_finance_annual_membership_unique on public.club_finance_transactions(member_id,membership_year) where transaction_type='membership' and membership_period='annual';
create index if not exists club_finance_transactions_date_idx on public.club_finance_transactions(transaction_date desc,created_at desc);
create index if not exists club_finance_transactions_member_idx on public.club_finance_transactions(member_id,membership_year) where transaction_type='membership';

create table if not exists public.club_finance_audit_log (
  id bigint generated always as identity primary key,
  transaction_id uuid,
  action text not null check (action in ('INSERT','UPDATE','DELETE')),
  actor_id uuid references auth.users(id),
  changed_at timestamptz not null default now(),
  old_data jsonb,
  new_data jsonb
);
create index if not exists club_finance_audit_log_changed_at_idx on public.club_finance_audit_log(changed_at desc);

create or replace function public.club_finance_validate_membership()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.transaction_type = 'membership' then
    perform pg_advisory_xact_lock(hashtextextended(new.member_id::text || ':' || new.membership_year::text,0));
    if new.membership_period = 'annual' and exists (
      select 1 from public.club_finance_transactions t where t.transaction_type='membership'
        and t.member_id=new.member_id and t.membership_year=new.membership_year
        and t.membership_period='monthly' and t.id<>new.id
    ) then raise exception 'Član već ima evidentirane mesečne uplate za ovu godinu. Prvo ispravite postojeće uplate.'; end if;
    if new.membership_period = 'monthly' and exists (
      select 1 from public.club_finance_transactions t where t.transaction_type='membership'
        and t.member_id=new.member_id and t.membership_year=new.membership_year
        and t.membership_period='annual' and t.id<>new.id
    ) then raise exception 'Član već ima godišnju uplatu za ovu godinu.'; end if;
  end if;
  new.updated_at=now();
  return new;
end; $$;
drop trigger if exists club_finance_validate_membership_trigger on public.club_finance_transactions;
create trigger club_finance_validate_membership_trigger before insert or update on public.club_finance_transactions for each row execute function public.club_finance_validate_membership();

create or replace function public.club_finance_audit_row()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op='INSERT' then
    insert into public.club_finance_audit_log(transaction_id,action,actor_id,new_data) values(new.id,tg_op,auth.uid(),to_jsonb(new)); return new;
  elsif tg_op='UPDATE' then
    insert into public.club_finance_audit_log(transaction_id,action,actor_id,old_data,new_data) values(new.id,tg_op,auth.uid(),to_jsonb(old),to_jsonb(new)); return new;
  else
    insert into public.club_finance_audit_log(transaction_id,action,actor_id,old_data) values(old.id,tg_op,auth.uid(),to_jsonb(old)); return old;
  end if;
end; $$;
revoke all on function public.club_finance_audit_row() from public, anon, authenticated;
drop trigger if exists club_finance_audit_trigger on public.club_finance_transactions;
create trigger club_finance_audit_trigger after insert or update or delete on public.club_finance_transactions for each row execute function public.club_finance_audit_row();

alter table public.club_finance_settings enable row level security;
alter table public.club_finance_transactions enable row level security;
alter table public.club_finance_audit_log enable row level security;
drop policy if exists "Approved members can view finance settings" on public.club_finance_settings;
create policy "Approved members can view finance settings" on public.club_finance_settings for select to authenticated using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.approved=true));
drop policy if exists "Admins can update finance settings" on public.club_finance_settings;
create policy "Admins can update finance settings" on public.club_finance_settings for update to authenticated using(public.is_current_user_admin()) with check(public.is_current_user_admin());
drop policy if exists "Approved members can view finance transactions" on public.club_finance_transactions;
create policy "Approved members can view finance transactions" on public.club_finance_transactions for select to authenticated using(exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.approved=true));
drop policy if exists "Admins can insert finance transactions" on public.club_finance_transactions;
create policy "Admins can insert finance transactions" on public.club_finance_transactions for insert to authenticated with check(public.is_current_user_admin() and created_by=(select auth.uid()));
drop policy if exists "Admins can update finance transactions" on public.club_finance_transactions;
create policy "Admins can update finance transactions" on public.club_finance_transactions for update to authenticated using(public.is_current_user_admin()) with check(public.is_current_user_admin());
drop policy if exists "Admins can delete finance transactions" on public.club_finance_transactions;
create policy "Admins can delete finance transactions" on public.club_finance_transactions for delete to authenticated using(public.is_current_user_admin());
drop policy if exists "Admins can view finance audit log" on public.club_finance_audit_log;
create policy "Admins can view finance audit log" on public.club_finance_audit_log for select to authenticated using(public.is_current_user_admin());

revoke all on public.club_finance_settings from anon,authenticated;
grant select,update on public.club_finance_settings to authenticated;
revoke all on public.club_finance_transactions from anon,authenticated;
grant select,insert,update,delete on public.club_finance_transactions to authenticated;
revoke all on public.club_finance_audit_log from anon,authenticated;
grant select on public.club_finance_audit_log to authenticated;

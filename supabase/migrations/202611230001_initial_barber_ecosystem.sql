-- Barber Ecosystem initial schema
-- PostgreSQL / Supabase. All public tables enable RLS.
create extension if not exists pgcrypto;

create type public.ownership_type as enum ('individual','company');
create type public.org_role as enum ('owner','co_owner','organization_admin','billing_manager','viewer');
create type public.shop_role as enum ('shop_manager','branch_manager','barber','receptionist','viewer');
create type public.appointment_status as enum ('pending','confirmed','completed','cancelled','no_show');
create type public.campaign_segment as enum ('all_customers','inactive_20_days','inactive_30_days','vip','nearby');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  phone text,
  phone_verified_at timestamptz,
  email_verified_at timestamptz,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  ownership_type public.ownership_type not null,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create table public.organization_members (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.org_role not null,
  joined_at timestamptz not null default now(),
  primary key (organization_id,user_id)
);

create table public.organization_owners (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete restrict,
  ownership_percent numeric(5,2) not null check (ownership_percent > 0 and ownership_percent <= 100),
  primary key (organization_id,user_id)
);

create table public.shops (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  description text,
  public_listing boolean not null default true,
  claimed_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.shop_members (
  shop_id uuid not null references public.shops(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.shop_role not null,
  primary key (shop_id,user_id)
);

create table public.branches (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  name text not null,
  address text,
  city text,
  country text,
  latitude double precision,
  longitude double precision,
  is_primary boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  check ((latitude is null and longitude is null) or (latitude between -90 and 90 and longitude between -180 and 180))
);
create unique index branches_one_primary_per_shop on public.branches(shop_id) where is_primary;

create table public.barber_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  bio text,
  years_experience integer check (years_experience >= 0),
  seeking_work boolean not null default false,
  preferred_city text,
  customer_base_description text,
  updated_at timestamptz not null default now()
);

create table public.services (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id) on delete cascade,
  name text not null,
  duration_minutes integer not null check (duration_minutes between 5 and 600),
  price numeric(10,2) not null check (price >= 0),
  currency char(3) not null default 'TRY',
  is_active boolean not null default true
);

create table public.branch_barbers (
  branch_id uuid not null references public.branches(id) on delete cascade,
  barber_user_id uuid not null references auth.users(id) on delete cascade,
  is_active boolean not null default true,
  primary key (branch_id,barber_user_id)
);

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  display_name text not null,
  phone text,
  visits_count integer not null default 0 check (visits_count >= 0),
  loyalty_points integer not null default 0 check (loyalty_points >= 0),
  is_vip boolean not null default false,
  last_visit_at timestamptz,
  created_at timestamptz not null default now()
);
create index customers_branch_phone_idx on public.customers(branch_id,phone);

create table public.appointments (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id) on delete cascade,
  customer_id uuid not null references public.customers(id) on delete restrict,
  barber_user_id uuid references auth.users(id) on delete set null,
  service_id uuid references public.services(id) on delete set null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status public.appointment_status not null default 'pending',
  customer_note text,
  cancelled_by uuid references auth.users(id) on delete set null,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);
create index appointments_branch_start_idx on public.appointments(branch_id,starts_at);
create index appointments_customer_status_idx on public.appointments(customer_id,status);

create table public.loyalty_transactions (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete cascade,
  points_delta integer not null check (points_delta <> 0),
  reason text not null,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table public.campaigns (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id) on delete cascade,
  title text not null,
  message text not null,
  segment public.campaign_segment not null,
  scheduled_at timestamptz,
  status text not null default 'draft' check (status in ('draft','scheduled','sent','cancelled')),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create table public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  monthly_price numeric(10,2) not null check (monthly_price >= 0),
  currency char(3) not null default 'USD',
  included_shops integer not null default 1 check (included_shops >= 1),
  included_branches_per_shop integer not null default 1 check (included_branches_per_shop >= 1),
  is_active boolean not null default true
);

create table public.organization_subscriptions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  plan_id uuid not null references public.subscription_plans(id),
  status text not null default 'trial' check (status in ('trial','active','past_due','cancelled','expired')),
  current_period_start timestamptz,
  current_period_end timestamptz,
  created_at timestamptz not null default now()
);

create table public.subscription_addons (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.organization_subscriptions(id) on delete cascade,
  item_type text not null check (item_type in ('extra_shop','extra_branch')),
  quantity integer not null default 1 check (quantity > 0),
  unit_monthly_price numeric(10,2) not null check (unit_monthly_price >= 0),
  currency char(3) not null default 'USD'
);

-- Authorization: membership is the source of truth, never user-editable metadata.
alter table public.profiles enable row level security;
alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.organization_owners enable row level security;
alter table public.shops enable row level security;
alter table public.shop_members enable row level security;
alter table public.branches enable row level security;
alter table public.barber_profiles enable row level security;
alter table public.services enable row level security;
alter table public.branch_barbers enable row level security;
alter table public.customers enable row level security;
alter table public.appointments enable row level security;
alter table public.loyalty_transactions enable row level security;
alter table public.campaigns enable row level security;
alter table public.subscription_plans enable row level security;
alter table public.organization_subscriptions enable row level security;
alter table public.subscription_addons enable row level security;

create policy "profile self select" on public.profiles for select to authenticated using (id = (select auth.uid()));
create policy "profile self insert" on public.profiles for insert to authenticated with check (id = (select auth.uid()));
create policy "profile self update" on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy "org members read org" on public.organizations for select to authenticated using (
  exists (select 1 from public.organization_members m where m.organization_id = id and m.user_id = (select auth.uid()))
);
create policy "authenticated create org" on public.organizations for insert to authenticated with check (created_by = (select auth.uid()));
create policy "org admins update org" on public.organizations for update to authenticated using (
  exists (select 1 from public.organization_members m where m.organization_id = id and m.user_id = (select auth.uid()) and m.role in ('owner','co_owner','organization_admin'))
) with check (
  exists (select 1 from public.organization_members m where m.organization_id = id and m.user_id = (select auth.uid()) and m.role in ('owner','co_owner','organization_admin'))
);

create policy "members read own org roster" on public.organization_members for select to authenticated using (
  user_id = (select auth.uid()) or exists (select 1 from public.organization_members m where m.organization_id = organization_id and m.user_id = (select auth.uid()))
);
create policy "org owner manage members" on public.organization_members for all to authenticated using (
  exists (select 1 from public.organization_members m where m.organization_id = organization_id and m.user_id = (select auth.uid()) and m.role in ('owner','co_owner','organization_admin'))
) with check (
  exists (select 1 from public.organization_members m where m.organization_id = organization_id and m.user_id = (select auth.uid()) and m.role in ('owner','co_owner','organization_admin'))
);
create policy "org members read ownership" on public.organization_owners for select to authenticated using (
  exists (select 1 from public.organization_members m where m.organization_id = organization_id and m.user_id = (select auth.uid()))
);
create policy "org owners manage ownership" on public.organization_owners for all to authenticated using (
  exists (select 1 from public.organization_members m where m.organization_id = organization_id and m.user_id = (select auth.uid()) and m.role in ('owner','co_owner'))
) with check (
  exists (select 1 from public.organization_members m where m.organization_id = organization_id and m.user_id = (select auth.uid()) and m.role in ('owner','co_owner'))
);

create policy "org members read shops" on public.shops for select to authenticated using (
  exists (select 1 from public.organization_members m where m.organization_id = organization_id and m.user_id = (select auth.uid()))
);
create policy "org admins manage shops" on public.shops for all to authenticated using (
  exists (select 1 from public.organization_members m where m.organization_id = organization_id and m.user_id = (select auth.uid()) and m.role in ('owner','co_owner','organization_admin'))
) with check (
  exists (select 1 from public.organization_members m where m.organization_id = organization_id and m.user_id = (select auth.uid()) and m.role in ('owner','co_owner','organization_admin'))
);

create policy "shop members read shop membership" on public.shop_members for select to authenticated using (
  user_id = (select auth.uid()) or exists (select 1 from public.shop_members sm where sm.shop_id = shop_id and sm.user_id = (select auth.uid()) and sm.role in ('shop_manager','branch_manager'))
);
create policy "shop managers manage shop membership" on public.shop_members for all to authenticated using (
  exists (select 1 from public.shop_members sm where sm.shop_id = shop_id and sm.user_id = (select auth.uid()) and sm.role = 'shop_manager')
) with check (
  exists (select 1 from public.shop_members sm where sm.shop_id = shop_id and sm.user_id = (select auth.uid()) and sm.role = 'shop_manager')
);

create policy "branch access read" on public.branches for select to authenticated using (
  exists (select 1 from public.shop_members sm where sm.shop_id = branches.shop_id and sm.user_id = (select auth.uid()))
  or exists (select 1 from public.organization_members om join public.shops s on s.organization_id = om.organization_id where s.id = branches.shop_id and om.user_id = (select auth.uid()))
);
create policy "shop managers manage branches" on public.branches for all to authenticated using (
  exists (select 1 from public.shop_members sm where sm.shop_id = branches.shop_id and sm.user_id = (select auth.uid()) and sm.role = 'shop_manager')
  or exists (select 1 from public.organization_members om join public.shops s on s.organization_id = om.organization_id where s.id = branches.shop_id and om.user_id = (select auth.uid()) and om.role in ('owner','co_owner','organization_admin'))
) with check (
  exists (select 1 from public.shop_members sm where sm.shop_id = branches.shop_id and sm.user_id = (select auth.uid()) and sm.role = 'shop_manager')
  or exists (select 1 from public.organization_members om join public.shops s on s.organization_id = om.organization_id where s.id = branches.shop_id and om.user_id = (select auth.uid()) and om.role in ('owner','co_owner','organization_admin'))
);

-- Operational tables: branch staff can read; only managers can write.
create policy "branch staff read services" on public.services for select to authenticated using (
  exists (select 1 from public.shop_members sm join public.branches b on b.shop_id = sm.shop_id where b.id = branch_id and sm.user_id = (select auth.uid()))
  or exists (select 1 from public.organization_members om join public.shops s on s.organization_id = om.organization_id join public.branches b on b.shop_id = s.id where b.id = branch_id and om.user_id = (select auth.uid()))
);
create policy "branch managers manage services" on public.services for all to authenticated using (
  exists (select 1 from public.shop_members sm join public.branches b on b.shop_id = sm.shop_id where b.id = branch_id and sm.user_id = (select auth.uid()) and sm.role in ('shop_manager','branch_manager'))
) with check (
  exists (select 1 from public.shop_members sm join public.branches b on b.shop_id = sm.shop_id where b.id = branch_id and sm.user_id = (select auth.uid()) and sm.role in ('shop_manager','branch_manager'))
);

create policy "barber own profile read" on public.barber_profiles for select to authenticated using (user_id = (select auth.uid()));
create policy "barber own profile insert" on public.barber_profiles for insert to authenticated with check (user_id = (select auth.uid()));
create policy "barber own profile update" on public.barber_profiles for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy "branch staff read barbers" on public.branch_barbers for select to authenticated using (
  barber_user_id = (select auth.uid()) or exists (select 1 from public.shop_members sm join public.branches b on b.shop_id = sm.shop_id where b.id = branch_id and sm.user_id = (select auth.uid()))
);
create policy "branch managers assign barbers" on public.branch_barbers for all to authenticated using (
  exists (select 1 from public.shop_members sm join public.branches b on b.shop_id = sm.shop_id where b.id = branch_id and sm.user_id = (select auth.uid()) and sm.role in ('shop_manager','branch_manager'))
) with check (
  exists (select 1 from public.shop_members sm join public.branches b on b.shop_id = sm.shop_id where b.id = branch_id and sm.user_id = (select auth.uid()) and sm.role in ('shop_manager','branch_manager'))
);

create policy "branch staff read customers" on public.customers for select to authenticated using (
  user_id = (select auth.uid()) or exists (select 1 from public.shop_members sm join public.branches b on b.shop_id = sm.shop_id where b.id = branch_id and sm.user_id = (select auth.uid()))
);
create policy "branch staff create customers" on public.customers for insert to authenticated with check (
  exists (select 1 from public.shop_members sm join public.branches b on b.shop_id = sm.shop_id where b.id = branch_id and sm.user_id = (select auth.uid()) and sm.role in ('shop_manager','branch_manager','barber','receptionist'))
);
create policy "branch staff update customers" on public.customers for update to authenticated using (
  exists (select 1 from public.shop_members sm join public.branches b on b.shop_id = sm.shop_id where b.id = branch_id and sm.user_id = (select auth.uid()) and sm.role in ('shop_manager','branch_manager','barber','receptionist'))
) with check (
  exists (select 1 from public.shop_members sm join public.branches b on b.shop_id = sm.shop_id where b.id = branch_id and sm.user_id = (select auth.uid()) and sm.role in ('shop_manager','branch_manager','barber','receptionist'))
);

create policy "branch participants read appointments" on public.appointments for select to authenticated using (
  barber_user_id = (select auth.uid()) or exists (select 1 from public.customers c where c.id = customer_id and c.user_id = (select auth.uid()))
  or exists (select 1 from public.shop_members sm join public.branches b on b.shop_id = sm.shop_id where b.id = branch_id and sm.user_id = (select auth.uid()))
);
create policy "branch staff create appointments" on public.appointments for insert to authenticated with check (
  exists (select 1 from public.shop_members sm join public.branches b on b.shop_id = sm.shop_id where b.id = branch_id and sm.user_id = (select auth.uid()) and sm.role in ('shop_manager','branch_manager','barber','receptionist'))
  or exists (select 1 from public.customers c where c.id = customer_id and c.user_id = (select auth.uid()))
);
create policy "branch staff update appointments" on public.appointments for update to authenticated using (
  exists (select 1 from public.shop_members sm join public.branches b on b.shop_id = sm.shop_id where b.id = branch_id and sm.user_id = (select auth.uid()) and sm.role in ('shop_manager','branch_manager','barber','receptionist'))
  or exists (select 1 from public.customers c where c.id = customer_id and c.user_id = (select auth.uid()))
) with check (
  exists (select 1 from public.shop_members sm join public.branches b on b.shop_id = sm.shop_id where b.id = branch_id and sm.user_id = (select auth.uid()) and sm.role in ('shop_manager','branch_manager','barber','receptionist'))
  or exists (select 1 from public.customers c where c.id = customer_id and c.user_id = (select auth.uid()))
);

create policy "customer or branch staff read loyalty" on public.loyalty_transactions for select to authenticated using (
  exists (select 1 from public.customers c where c.id = customer_id and c.user_id = (select auth.uid()))
  or exists (select 1 from public.customers c join public.shop_members sm on sm.shop_id = (select b.shop_id from public.branches b where b.id = c.branch_id) where c.id = customer_id and sm.user_id = (select auth.uid()))
);
create policy "branch managers create loyalty" on public.loyalty_transactions for insert to authenticated with check (
  exists (select 1 from public.customers c join public.branches b on b.id = c.branch_id join public.shop_members sm on sm.shop_id = b.shop_id where c.id = customer_id and sm.user_id = (select auth.uid()) and sm.role in ('shop_manager','branch_manager'))
);

create policy "branch staff read campaigns" on public.campaigns for select to authenticated using (
  exists (select 1 from public.shop_members sm join public.branches b on b.shop_id = sm.shop_id where b.id = branch_id and sm.user_id = (select auth.uid()))
);
create policy "branch managers manage campaigns" on public.campaigns for all to authenticated using (
  exists (select 1 from public.shop_members sm join public.branches b on b.shop_id = sm.shop_id where b.id = branch_id and sm.user_id = (select auth.uid()) and sm.role in ('shop_manager','branch_manager'))
) with check (
  exists (select 1 from public.shop_members sm join public.branches b on b.shop_id = sm.shop_id where b.id = branch_id and sm.user_id = (select auth.uid()) and sm.role in ('shop_manager','branch_manager'))
);

create policy "active plans public read" on public.subscription_plans for select to anon, authenticated using (is_active);
create policy "org billing roles read subscriptions" on public.organization_subscriptions for select to authenticated using (
  exists (select 1 from public.organization_members m where m.organization_id = organization_id and m.user_id = (select auth.uid()) and m.role in ('owner','co_owner','organization_admin','billing_manager'))
);
create policy "org billing roles read addons" on public.subscription_addons for select to authenticated using (
  exists (select 1 from public.organization_subscriptions s join public.organization_members m on m.organization_id = s.organization_id where s.id = subscription_id and m.user_id = (select auth.uid()) and m.role in ('owner','co_owner','organization_admin','billing_manager'))
);

-- Avoid public mutation of subscription records. Provisioning and billing updates are server-side only.

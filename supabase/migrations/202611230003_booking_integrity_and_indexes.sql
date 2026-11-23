-- Barber Ecosystem: booking integrity and query indexes
create extension if not exists btree_gist;

-- A customer may have only one active booking at a time.
create unique index appointments_one_active_per_customer
  on public.appointments(customer_id)
  where status in ('pending','confirmed');

-- A barber cannot be assigned overlapping active appointments.
alter table public.appointments
  add constraint appointments_no_barber_overlap
  exclude using gist (
    barber_user_id with =,
    tstzrange(starts_at, ends_at, '[)') with &&
  )
  where (barber_user_id is not null and status in ('pending','confirmed'));

-- Supporting indexes for joins, filtering and foreign-key maintenance.
create index if not exists organization_members_user_idx on public.organization_members(user_id);
create index if not exists organization_owners_user_idx on public.organization_owners(user_id);
create index if not exists shops_organization_idx on public.shops(organization_id);
create index if not exists shop_members_user_idx on public.shop_members(user_id);
create index if not exists appointments_barber_idx on public.appointments(barber_user_id);
create index if not exists appointments_service_idx on public.appointments(service_id);
create index if not exists appointments_cancelled_by_idx on public.appointments(cancelled_by);
create index if not exists branch_barbers_user_idx on public.branch_barbers(barber_user_id);
create index if not exists customers_user_idx on public.customers(user_id);
create index if not exists campaigns_branch_idx on public.campaigns(branch_id);
create index if not exists campaigns_created_by_idx on public.campaigns(created_by);
create index if not exists loyalty_customer_idx on public.loyalty_transactions(customer_id);
create index if not exists loyalty_created_by_idx on public.loyalty_transactions(created_by);
create index if not exists org_subscriptions_org_idx on public.organization_subscriptions(organization_id);
create index if not exists org_subscriptions_plan_idx on public.organization_subscriptions(plan_id);
create index if not exists addons_subscription_idx on public.subscription_addons(subscription_id);
create index if not exists services_branch_idx on public.services(branch_id);
create index if not exists organizations_created_by_idx on public.organizations(created_by);

-- Let organization owners/admins manage branch operational data.
create policy "organization admins manage services"
on public.services for all to authenticated
using (
  exists (
    select 1 from public.branches b
    join public.shops s on s.id = b.shop_id
    join public.organization_members om on om.organization_id = s.organization_id
    where b.id = services.branch_id
      and om.user_id = (select auth.uid())
      and om.role in ('owner','co_owner','organization_admin')
  )
)
with check (
  exists (
    select 1 from public.branches b
    join public.shops s on s.id = b.shop_id
    join public.organization_members om on om.organization_id = s.organization_id
    where b.id = services.branch_id
      and om.user_id = (select auth.uid())
      and om.role in ('owner','co_owner','organization_admin')
  )
);

create policy "organization admins read customers"
on public.customers for select to authenticated
using (
  exists (
    select 1 from public.branches b
    join public.shops s on s.id = b.shop_id
    join public.organization_members om on om.organization_id = s.organization_id
    where b.id = customers.branch_id
      and om.user_id = (select auth.uid())
      and om.role in ('owner','co_owner','organization_admin','billing_manager','viewer')
  )
);

create policy "organization admins manage customers"
on public.customers for all to authenticated
using (
  exists (
    select 1 from public.branches b
    join public.shops s on s.id = b.shop_id
    join public.organization_members om on om.organization_id = s.organization_id
    where b.id = customers.branch_id
      and om.user_id = (select auth.uid())
      and om.role in ('owner','co_owner','organization_admin')
  )
)
with check (
  exists (
    select 1 from public.branches b
    join public.shops s on s.id = b.shop_id
    join public.organization_members om on om.organization_id = s.organization_id
    where b.id = customers.branch_id
      and om.user_id = (select auth.uid())
      and om.role in ('owner','co_owner','organization_admin')
  )
);

create policy "organization admins read appointments"
on public.appointments for select to authenticated
using (
  exists (
    select 1 from public.branches b
    join public.shops s on s.id = b.shop_id
    join public.organization_members om on om.organization_id = s.organization_id
    where b.id = appointments.branch_id
      and om.user_id = (select auth.uid())
      and om.role in ('owner','co_owner','organization_admin','billing_manager','viewer')
  )
);

create policy "organization admins manage appointments"
on public.appointments for all to authenticated
using (
  exists (
    select 1 from public.branches b
    join public.shops s on s.id = b.shop_id
    join public.organization_members om on om.organization_id = s.organization_id
    where b.id = appointments.branch_id
      and om.user_id = (select auth.uid())
      and om.role in ('owner','co_owner','organization_admin')
  )
)
with check (
  exists (
    select 1 from public.branches b
    join public.shops s on s.id = b.shop_id
    join public.organization_members om on om.organization_id = s.organization_id
    where b.id = appointments.branch_id
      and om.user_id = (select auth.uid())
      and om.role in ('owner','co_owner','organization_admin')
  )
);
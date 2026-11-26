-- Personal workflows use the scoped mobile functions. Management keeps its branch access.

alter policy "branch staff read customers" on public.customers
using (user_id=(select auth.uid()) or exists (
    select 1 from public.shop_members sm join public.branches b on b.shop_id=sm.shop_id
    where b.id=customers.branch_id and sm.user_id=(select auth.uid())
      and sm.role in ('shop_manager','branch_manager','receptionist')
  ));

alter policy "branch staff create customers" on public.customers
with check (exists (
    select 1 from public.shop_members sm join public.branches b on b.shop_id=sm.shop_id
    where b.id=customers.branch_id and sm.user_id=(select auth.uid())
      and sm.role in ('shop_manager','branch_manager','receptionist')
  ));

alter policy "branch staff update customers" on public.customers
using (exists (
    select 1 from public.shop_members sm join public.branches b on b.shop_id=sm.shop_id
    where b.id=customers.branch_id and sm.user_id=(select auth.uid())
      and sm.role in ('shop_manager','branch_manager','receptionist')
  ))
with check (exists (
    select 1 from public.shop_members sm join public.branches b on b.shop_id=sm.shop_id
    where b.id=customers.branch_id and sm.user_id=(select auth.uid())
      and sm.role in ('shop_manager','branch_manager','receptionist')
  ));

alter policy "branch participants read appointments" on public.appointments
using (exists (select 1 from public.customers c where c.id=appointments.customer_id and c.user_id=(select auth.uid())) or exists (
    select 1 from public.shop_members sm join public.branches b on b.shop_id=sm.shop_id
    where b.id=appointments.branch_id and sm.user_id=(select auth.uid())
      and sm.role in ('shop_manager','branch_manager','receptionist')
  ));

alter policy "branch staff create appointments" on public.appointments
with check (exists (
    select 1 from public.shop_members sm join public.branches b on b.shop_id=sm.shop_id
    where b.id=appointments.branch_id and sm.user_id=(select auth.uid())
      and sm.role in ('shop_manager','branch_manager','receptionist')
  ));

alter policy "branch staff update appointments" on public.appointments
using (exists (
    select 1 from public.shop_members sm join public.branches b on b.shop_id=sm.shop_id
    where b.id=appointments.branch_id and sm.user_id=(select auth.uid())
      and sm.role in ('shop_manager','branch_manager','receptionist')
  ))
with check (exists (
    select 1 from public.shop_members sm join public.branches b on b.shop_id=sm.shop_id
    where b.id=appointments.branch_id and sm.user_id=(select auth.uid())
      and sm.role in ('shop_manager','branch_manager','receptionist')
  ));

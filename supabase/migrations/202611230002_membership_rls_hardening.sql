-- Security correction: avoid recursive RLS policies on membership tables.
drop policy if exists "members read own org roster" on public.organization_members;
drop policy if exists "org owner manage members" on public.organization_members;
drop policy if exists "shop members read shop membership" on public.shop_members;
drop policy if exists "shop managers manage shop membership" on public.shop_members;

-- A user can read only their own membership rows. Administrative membership
-- changes (invites, role changes, removals) must be implemented through a
-- trusted Edge Function after validating the caller's organization/shop role.
create policy "users read own organization memberships"
on public.organization_members for select to authenticated
using (user_id = (select auth.uid()));

create policy "creator can claim organization owner membership"
on public.organization_members for insert to authenticated
with check (
  user_id = (select auth.uid())
  and role = 'owner'
  and exists (
    select 1 from public.organizations o
    where o.id = organization_id and o.created_by = (select auth.uid())
  )
);

create policy "users read own shop memberships"
on public.shop_members for select to authenticated
using (user_id = (select auth.uid()));

-- Public directory discovery is intentionally limited to claimed/unclaimed
-- listing metadata. Customer-facing directory views will be added separately
-- with security_invoker=true and a carefully limited column set.

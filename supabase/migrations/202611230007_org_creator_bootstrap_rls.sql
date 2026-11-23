-- Allow the creator to see the organization they just created so the
-- self-owner membership INSERT policy can verify created_by under RLS.
create policy "organization creator reads own organization"
on public.organizations for select to authenticated
using (created_by = (select auth.uid()));
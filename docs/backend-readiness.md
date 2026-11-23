# Backend readiness and next setup

## Database migration files
- `202611230001_initial_barber_ecosystem.sql`: first-pass multi-tenant entities, relationships, indexes and RLS.
- `202611230002_membership_rls_hardening.sql`: removes recursive membership-table RLS and restricts self-readable membership rows.

## Important implementation boundary
These migrations are committed to GitHub but have **not** been applied to a Supabase database. The only Supabase project currently visible in the connected account is an inactive project named ClinicPro Dental Online. It is unrelated to Barber Ecosystem and must not be reused for this product.

Before database provisioning, select the Supabase organization and review any quoted project cost. Once the dedicated Barber Ecosystem project is available and active, apply migrations in order, run SQL verification and Supabase security/performance advisors, then implement trusted Edge Functions for organization/shop invitations, membership administration, booking conflict prevention, campaign delivery and billing webhooks.

## Known items before production
- Add transactional owner-membership provisioning during organization creation (or use a trusted Edge Function).
- Enforce the 90-minute cancellation warning in the client and preserve cancellation permission at all times.
- Add a database-level exclusion/transaction strategy to prevent barber/branch appointment overlaps and duplicate active customer bookings.
- Add public directory read models with only safe fields; do not expose customer phone numbers or internal records.
- Add subscription capacity checks before activating additional shops/branches.
- Validate ownership percentages total 100% before marking company ownership as verified.
- Add invitation lifecycle, phone/email verification workflow, audit log, notifications, campaign consent and unsubscribe handling.

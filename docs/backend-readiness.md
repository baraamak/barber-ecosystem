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


## Supabase project provisioned and schema applied
- Dedicated project: `barber-ecosystem` (region `ap-southeast-1`, PostgreSQL 17).
- Project reference: `lhgkplxlupbmlmuaqykt`.
- Applied migrations: initial schema, membership RLS hardening, booking integrity/indexes, extension schema fix, profile account type.
- Confirmed 17 public tables with RLS enabled.
- Confirmed booking constraints: one active appointment per customer and no overlapping active appointments for the same barber.
- Security advisor returned no findings after moving `btree_gist` into `extensions`.
- Email/password registration and login are now present in `auth.html`; the dashboard redirects unauthenticated visitors to it.

## Current beta limitations
- The dashboard's operational lists and booking form still use browser-local demo data; they are not yet reading/writing Supabase tables.
- Account creation supports email/password only. SMS verification, phone-based login, role invitations, organization provisioning and server-side membership management are not implemented yet.
- The current RLS policy set is an initial beta baseline. Before real customer data or public launch, complete an end-to-end role matrix test and replace any manager workflows requiring roster visibility with trusted server-side operations.
- GitHub Pages deployment workflow is committed; deployment URL and workflow success must still be verified in repository Actions/Pages settings.


## Beta 0.3 — connected management flows
- Dashboard now requires an authenticated Supabase session.
- First sign-in creates the user's profile row when missing.
- Organization onboarding creates an organization, its creator-owner membership, the first shop, and its primary branch through authenticated Data API calls.
- Organization owners/admins can create and list branch services.
- Appointment creation now finds or creates a customer by branch + phone, calculates the end time from service duration, and writes the appointment to Supabase.
- Appointment status changes and dashboard counts are read from Supabase.
- Migration `202611230006_org_admin_operational_access.sql` grants organization owner/admin access to operational branch data.
- Migration `202611230007_org_creator_bootstrap_rls.sql` fixes the RLS bootstrap path so the organization creator can insert their first owner membership.

## Verification snapshot (2026-11-23)
- 17 public tables; all 17 have RLS enabled.
- Database checks confirm the active-customer booking unique index and barber-overlap exclusion constraint exist.
- Supabase security advisor returned no findings after the latest migration.
- Performance advisor still reports INFO unused indexes (expected while tables are empty) and WARN multiple permissive policies. These are performance cleanup items, not security advisor findings; consolidate policies before production load testing.
- No Edge Functions are deployed yet.

## Beta test sequence
1. Open `auth.html`, create a test account as Shop Owner, and confirm the email if the project requires email confirmation.
2. Sign in and open **المؤسسة والشركاء**.
3. Create a test organization, first shop, and primary branch.
4. Open **الخدمات والأسعار**, add at least one service.
5. Open **الحجوزات**, create a booking with a test customer name and phone.
6. Refresh the page and verify the organization, service, and booking remain present.
7. Change the booking status and verify it persists after refresh.
8. Try to create a second active booking for the same customer; the database should reject it.

## Remaining before calling this a final beta
- Execute a real browser test using at least two test accounts and confirm RLS isolation between unrelated organizations.
- Add secure invitation/membership management through a trusted Edge Function.
- Complete customer and barber-facing screens, public nearby shop discovery, jobs/training listings, campaigns/notifications, loyalty redemption, and subscription capacity enforcement.
- Implement the 90-minute customer cancellation warning and server-side cancellation audit.
- Configure and verify hosting. The GitHub repository is currently private; GitHub Pages availability depends on the repository/account plan and Pages settings. Do not make the repository public without the owner's explicit approval.
- Add app icons, production PWA install checks, and then package Android/iOS with an appropriate wrapper/build pipeline.
- Do not use real customer personal data in this beta until the full privacy and role matrix has been tested.

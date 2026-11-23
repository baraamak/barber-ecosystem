# Architecture Decisions — Initial

## Domain hierarchy
`Organization → Shops → Branches`

A branch is part of a shop, not a separately subscribed shop. The organization owns the commercial subscription; invoice items represent the plan and add-ons such as additional shops and branches.

## Ownership and access
- Ownership types: `individual`, `company`.
- Record legal owners and ownership percentages separately from membership roles.
- Individual ownership has one active legal owner. Company ownership may have multiple partners; percentages should total 100% once ownership is finalized.
- Organization roles: `owner`, `co_owner`, `organization_admin`, `billing_manager`, `viewer`.
- Shop and branch membership must be independently scoped.
- Maintain audit records for sensitive ownership, billing, and permission changes.

## Suggested backend direction
Supabase is the proposed backend: PostgreSQL, Auth, Row Level Security, Storage, Realtime, and Edge Functions where appropriate. This is a direction, not a connected or provisioned backend yet.

## Security requirements
- Enable RLS on every table in exposed schemas.
- Policies must enforce organization/shop/branch scope using trusted membership data.
- UPDATE policies require both `USING` and `WITH CHECK`.
- Never use user-editable user metadata as an authorization source.
- Never expose service-role or secret keys in browser/mobile clients.
- Sensitive ownership and payment operations must run through trusted server-side workflows and create audit events.
- Do not assume that `TO authenticated` alone provides row-level authorization.

## Proposed technology choices — not yet finalized
Flutter is a candidate for mobile applications. Web framework and final client architecture remain open until a technical spike compares maintainability, delivery speed, and shared-code needs.
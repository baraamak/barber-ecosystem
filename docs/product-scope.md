# Product Scope — Barber Ecosystem

## Core platform
A multi-tenant platform serving customers, barbers, shop operators, academies, and platform administrators.

## Applications
- Customer app: discover participating shops, book appointments, manage cancellations, receive campaigns, and earn loyalty rewards.
- Barber app: manage professional profile and availability, view assigned appointments, track completed services and performance.
- Business app: manage shop operations, branches, staff, services, prices, customers, appointments, campaigns, and reports.
- Academy portal: manage trainers, courses, enrollment, attendance, and certificates.
- Super Admin: platform-level operations, subscriptions, support, and audit visibility.

## Booking rules
- A customer cannot create another active booking before completing or cancelling the current one.
- Customers may cancel at any time. If cancellation occurs within 90 minutes of the appointment, show a warning; do not block cancellation solely because of this window.
- A shop manager may cancel any booking.
- Authentication must verify both email and phone for customer and barber accounts.

## CRM and marketing
- Managers can send offers, discounts, and gifts to all customers.
- Support separate campaigns for customers absent for 20 days and 30 days, and distinct VIP segments.
- Future campaign types may include last-minute availability offers.

## Organization and commercial model
- Ownership type: individual or company; legal ownership is separate from operational roles.
- Organization contains shops; each shop contains branches.
- One primary branch is included with each shop entitlement. Additional branches are paid monthly line items.
- Organization subscription is centralized. Plans define included shop capacity; extra shops require an additional charge or plan upgrade.
- Organization roles: owner, co_owner, organization_admin, billing_manager, viewer.
- Shop and branch roles are separate and scoped; branch managers only access authorized branches.

## Rollout principles
Build the complete core scope, but release capabilities in controlled phases. Public listings for non-participating shops must clearly indicate that booking and platform campaigns are unavailable until the shop claims and activates its profile.
-- A barber explicitly offers a service at a given start time in an assigned branch.
create table public.offered_times (
  id uuid primary key default gen_random_uuid(),
  barber_id uuid not null references auth.users on delete cascade,
  service_id uuid not null references public.services on delete cascade,
  starts_at timestamptz not null,
  unique(barber_id,service_id,starts_at)
);
alter table public.offered_times enable row level security;
revoke all on public.offered_times from public, anon, authenticated;

create function public.mobile_barber_services()
returns table(id uuid, label text) language sql stable security definer set search_path='' as $$
 select s.id,concat(sh.name,' / ',b.name,' · ',s.name)
 from public.services s join public.branches b on b.id=s.branch_id join public.shops sh on sh.id=b.shop_id
 join public.branch_barbers bb on bb.branch_id=b.id
 where bb.barber_user_id=auth.uid() and bb.is_active and s.is_active and b.is_active and sh.public_listing order by 2
$$;

create function public.mobile_offer(service uuid, at_time timestamptz)
returns void language plpgsql security definer set search_path='' as $$
begin
 if at_time <= now() or at_time > now()+interval '72 hours' or not exists
 (select 1 from public.mobile_barber_services() s where s.id=service)
 then raise exception 'invalid_offer'; end if;
 insert into public.offered_times(barber_id,service_id,starts_at) values(auth.uid(),service,at_time) on conflict do nothing;
end $$;

create function public.mobile_open_times()
returns table(id uuid, starts_at timestamptz, shop text, branch text, city text, service text, barber text, price numeric, currency text)
language sql stable security definer set search_path='' as $$
 select t.id,t.starts_at,sh.name,b.name,b.city,s.name,p.display_name,s.price,s.currency::text
 from public.offered_times t join public.services s on s.id=t.service_id join public.branches b on b.id=s.branch_id
 join public.shops sh on sh.id=b.shop_id join public.profiles p on p.id=t.barber_id
 join public.branch_barbers bb on bb.branch_id=b.id and bb.barber_user_id=t.barber_id
 where bb.is_active and b.is_active and sh.public_listing and s.is_active and t.starts_at between now() and now()+interval '72 hours'
 and not exists(select 1 from public.appointments a where a.barber_user_id=t.barber_id and a.status in ('pending','confirmed')
 and tstzrange(a.starts_at,a.ends_at,'[)') && tstzrange(t.starts_at,t.starts_at+make_interval(mins=>s.duration_minutes),'[)'))
 order by t.starts_at,t.id
$$;

create function public.mobile_book(slot uuid)
returns void language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); customer uuid; person text; chosen record;
begin
 -- Serialize customer bookings across branches and devices.
 select display_name into person from public.profiles where id=actor and account_type='customer' for update;
 if not found then raise exception 'customer_required'; end if;
 if exists(select 1 from public.appointments a join public.customers c on c.id=a.customer_id
 where c.user_id=actor and a.status in ('pending','confirmed')) then raise exception 'active_booking'; end if;
 select t.*,s.branch_id,s.duration_minutes into chosen from public.offered_times t join public.services s on s.id=t.service_id
 where t.id=slot for update of t;
 if not found or not exists(select 1 from public.mobile_open_times() o where o.id=slot) then raise exception 'slot_taken'; end if;
 select id into customer from public.customers where branch_id=chosen.branch_id and user_id=actor order by created_at limit 1;
 if customer is null then
 insert into public.customers(branch_id,user_id,display_name) values(chosen.branch_id,actor,person) returning id into customer;
 end if;
 insert into public.appointments(branch_id,customer_id,barber_user_id,service_id,starts_at,ends_at,status)
 values(chosen.branch_id,customer,chosen.barber_id,chosen.service_id,chosen.starts_at,chosen.starts_at+make_interval(mins=>chosen.duration_minutes),'confirmed');
 delete from public.offered_times where id=slot;
end $$;

create function public.mobile_agenda()
returns table(id uuid, starts_at timestamptz, service text, counterpart text, branch text, status text)
language sql stable security definer set search_path='' as $$
 select a.id,a.starts_at,s.name,case when a.barber_user_id=auth.uid() then c.display_name else p.display_name end,b.name,a.status::text
 from public.appointments a join public.customers c on c.id=a.customer_id left join public.services s on s.id=a.service_id
 left join public.profiles p on p.id=a.barber_user_id join public.branches b on b.id=a.branch_id
 where (c.user_id=auth.uid() and a.status in ('confirmed','pending')) or
 (a.barber_user_id=auth.uid() and a.starts_at between now() and now()+interval '72 hours' and a.status in ('confirmed','pending'))
 order by a.starts_at
$$;

create function public.mobile_cancel(booking uuid, acknowledge_late boolean)
returns void language plpgsql security definer set search_path='' as $$
declare appt public.appointments; balance integer;
begin
 select a.* into appt from public.appointments a join public.customers c on c.id=a.customer_id
 where a.id=booking and c.user_id=auth.uid() and a.status in ('pending','confirmed') for update of a;
 if not found then raise exception 'booking_unavailable'; end if;
 if appt.starts_at between now() and now()+interval '90 minutes' then
 if not coalesce(acknowledge_late,false) then raise exception 'late_confirmation'; end if;
 select loyalty_points into balance from public.customers where id=appt.customer_id for update;
 if balance>0 then
 update public.customers set loyalty_points=loyalty_points-1 where id=appt.customer_id;
 insert into public.loyalty_transactions(customer_id,points_delta,reason,created_by) values(appt.customer_id,-1,'late_cancellation',auth.uid());
 end if;
 end if;
 update public.appointments set status='cancelled',cancelled_by=auth.uid(),cancelled_at=now() where id=booking;
end $$;

revoke all on function public.mobile_agenda(),public.mobile_open_times(),public.mobile_barber_services(),public.mobile_offer(uuid,timestamptz),public.mobile_book(uuid),public.mobile_cancel(uuid,boolean) from public,anon;
grant execute on function public.mobile_agenda(),public.mobile_open_times(),public.mobile_barber_services(),public.mobile_offer(uuid,timestamptz),public.mobile_book(uuid),public.mobile_cancel(uuid,boolean) to authenticated;

-- Only the organization administrator may issue a one-use branch invitation.
create table public.mobile_invites (
 token uuid primary key default gen_random_uuid(),
 branch_id uuid not null references public.branches on delete cascade,
 expires_at timestamptz not null default now()+interval '1 day'
);
alter table public.mobile_invites enable row level security;
revoke all on public.mobile_invites from public,anon,authenticated;

create function public.mobile_invite(branch uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare code uuid;
begin
 if not exists(select 1 from public.branches b join public.shops s on s.id=b.shop_id
 join public.organization_members m on m.organization_id=s.organization_id
 where b.id=branch and m.user_id=auth.uid() and m.role in ('owner','co_owner','organization_admin')) then raise exception 'forbidden'; end if;
 insert into public.mobile_invites(branch_id) values(branch) returning token into code;
 return code;
end $$;
create function public.mobile_join(code uuid) returns void
language plpgsql security definer set search_path='' as $$
declare branch uuid;
begin
 if not exists(select 1 from public.profiles where id=auth.uid() and account_type='barber') then raise exception 'forbidden'; end if;
 delete from public.mobile_invites where token=code and expires_at>now() returning branch_id into branch;
 if not found then raise exception 'invalid_invite'; end if;
 insert into public.branch_barbers(branch_id,barber_user_id) values(branch,auth.uid())
 on conflict(branch_id,barber_user_id) do update set is_active=true;
end $$;
revoke all on function public.mobile_join(uuid),public.mobile_invite(uuid) from public,anon;
grant execute on function public.mobile_join(uuid),public.mobile_invite(uuid) to authenticated;

create function public.mobile_staff()
returns table(branch_id uuid, barber_id uuid, name text)
language sql stable security definer set search_path='' as $$
 select bb.branch_id,bb.barber_user_id,p.display_name from public.branch_barbers bb
 join public.profiles p on p.id=bb.barber_user_id join public.branches b on b.id=bb.branch_id
 join public.shops s on s.id=b.shop_id join public.organization_members m on m.organization_id=s.organization_id
 where bb.is_active and m.user_id=auth.uid() and m.role in ('owner','co_owner','organization_admin')
 order by p.display_name
$$;
revoke all on function public.mobile_staff() from public,anon;
grant execute on function public.mobile_staff() to authenticated;

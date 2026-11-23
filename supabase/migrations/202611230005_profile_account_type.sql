create type public.account_type as enum ('customer','barber','shop_owner');
alter table public.profiles
  add column account_type public.account_type not null default 'customer';
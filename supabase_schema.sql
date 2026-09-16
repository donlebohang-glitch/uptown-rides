-- UPTOWN RIDES PHASE 1 DATABASE
create extension if not exists pgcrypto;

do $$ begin create type public.app_role as enum ('PASSENGER','DRIVER','ADMIN'); exception when duplicate_object then null; end $$;
do $$ begin create type public.user_status as enum ('ACTIVE','INACTIVE','SUSPENDED','PENDING'); exception when duplicate_object then null; end $$;
do $$ begin create type public.driver_approval as enum ('PENDING','APPROVED','SUSPENDED','DEACTIVATED'); exception when duplicate_object then null; end $$;
do $$ begin create type public.driver_availability as enum ('AVAILABLE','OFFLINE','ON_TRIP','BREAK'); exception when duplicate_object then null; end $$;
do $$ begin create type public.vehicle_status as enum ('AVAILABLE','ASSIGNED','IN_SERVICE','OUT_OF_SERVICE'); exception when duplicate_object then null; end $$;
do $$ begin create type public.insurance_status as enum ('VALID','EXPIRING','EXPIRED','NOT_VERIFIED'); exception when duplicate_object then null; end $$;
do $$ begin create type public.roadworthy_status as enum ('VALID','EXPIRING','EXPIRED','NOT_VERIFIED'); exception when duplicate_object then null; end $$;
do $$ begin create type public.subscription_status as enum ('FREE','PENDING','ACTIVE','PAYMENT_FAILED','CANCELLED','EXPIRED'); exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 first_name text,
 surname text,
 gender text,
 profile_picture_url text,
 mobile text,
 email text,
 emergency_contact_name text,
 emergency_contact_number text,
 home_location text,
 work_location text,
 preferred_routes text,
 preferred_travel_days text,
 morning_only boolean default false,
 morning_afternoon boolean default false,
 role public.app_role not null default 'PASSENGER',
 status public.user_status not null default 'PENDING',
 subscription_status public.subscription_status not null default 'FREE',
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.passengers (
 id uuid primary key default gen_random_uuid(),
 user_id uuid unique not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now()
);
create table if not exists public.drivers (
 id uuid primary key default gen_random_uuid(),
 user_id uuid unique not null references public.profiles(id) on delete cascade,
 approval_status public.driver_approval not null default 'PENDING',
 availability public.driver_availability not null default 'OFFLINE',
 licence_number text,
 licence_expiry date,
 assigned_vehicle_id uuid,
 vehicle_registration text,
 current_trip_status text default 'OFF_TRIP',
 created_at timestamptz not null default now()
);
create table if not exists public.vehicles (
 id uuid primary key default gen_random_uuid(),
 make text not null,
 model text not null,
 year integer,
 registration_number text unique not null,
 colour text,
 passenger_capacity integer not null default 4,
 assigned_driver_id uuid references public.drivers(id) on delete set null,
 status public.vehicle_status not null default 'AVAILABLE',
 insurance_status public.insurance_status not null default 'NOT_VERIFIED',
 roadworthy_status public.roadworthy_status not null default 'NOT_VERIFIED',
 service_information text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table public.drivers add constraint drivers_vehicle_fk foreign key (assigned_vehicle_id) references public.vehicles(id) on delete set null;

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
declare requested_role text;
begin
 requested_role := coalesce(new.raw_user_meta_data->>'requested_role','PASSENGER');
 if requested_role not in ('PASSENGER','DRIVER') then requested_role := 'PASSENGER'; end if;
 insert into public.profiles(id,first_name,surname,mobile,email,role,status)
 values(new.id,new.raw_user_meta_data->>'first_name',new.raw_user_meta_data->>'surname',new.raw_user_meta_data->>'mobile',new.email,requested_role::public.app_role,case when requested_role='DRIVER' then 'PENDING'::public.user_status else 'ACTIVE'::public.user_status end)
 on conflict(id) do nothing;
 if requested_role='DRIVER' then insert into public.drivers(user_id) values(new.id) on conflict(user_id) do nothing;
 else insert into public.passengers(user_id) values(new.id) on conflict(user_id) do nothing;
 end if;
 return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.profiles where id=auth.uid() and role='ADMIN'); $$;

alter table public.profiles enable row level security;
alter table public.passengers enable row level security;
alter table public.drivers enable row level security;
alter table public.vehicles enable row level security;

drop policy if exists profiles_select on public.profiles; create policy profiles_select on public.profiles for select to authenticated using (id=auth.uid() or public.is_admin());
drop policy if exists profiles_update on public.profiles; create policy profiles_update on public.profiles for update to authenticated using (id=auth.uid() or public.is_admin()) with check (id=auth.uid() or public.is_admin());
drop policy if exists profiles_admin_insert on public.profiles; create policy profiles_admin_insert on public.profiles for insert to authenticated with check (public.is_admin());

drop policy if exists passengers_self on public.passengers; create policy passengers_self on public.passengers for select to authenticated using (user_id=auth.uid() or public.is_admin());
drop policy if exists passengers_admin on public.passengers; create policy passengers_admin on public.passengers for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists drivers_self on public.drivers; create policy drivers_self on public.drivers for select to authenticated using (user_id=auth.uid() or public.is_admin());
drop policy if exists drivers_update on public.drivers; create policy drivers_update on public.drivers for update to authenticated using (user_id=auth.uid() or public.is_admin()) with check (user_id=auth.uid() or public.is_admin());
drop policy if exists drivers_admin on public.drivers; create policy drivers_admin on public.drivers for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists vehicles_read on public.vehicles; create policy vehicles_read on public.vehicles for select to authenticated using (public.is_admin() or exists(select 1 from public.drivers d where d.id=assigned_driver_id and d.user_id=auth.uid()));
drop policy if exists vehicles_admin on public.vehicles; create policy vehicles_admin on public.vehicles for all to authenticated using (public.is_admin()) with check (public.is_admin());

create index if not exists idx_profiles_role on public.profiles(role);
create index if not exists idx_profiles_status on public.profiles(status);
create index if not exists idx_drivers_approval on public.drivers(approval_status);
create index if not exists idx_vehicles_status on public.vehicles(status);

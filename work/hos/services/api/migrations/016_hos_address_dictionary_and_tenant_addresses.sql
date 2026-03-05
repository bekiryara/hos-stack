-- 016_hos_address_dictionary_and_tenant_addresses.sql
-- Address dictionary + tenant profile address for HOS ownership model.

create table if not exists address_cities (
  id bigserial primary key,
  name text not null,
  norm_name text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists address_districts (
  id bigserial primary key,
  city_id bigint not null references address_cities(id) on delete cascade,
  name text not null,
  norm_name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(city_id, norm_name)
);
create index if not exists address_districts_city_id_name_idx on address_districts(city_id, name);

create table if not exists address_neighborhoods (
  id bigserial primary key,
  district_id bigint not null references address_districts(id) on delete cascade,
  name text not null,
  norm_name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(district_id, norm_name)
);
create index if not exists address_neighborhoods_district_id_name_idx on address_neighborhoods(district_id, name);

create table if not exists address_manifest_versions (
  id bigserial primary key,
  source text null,
  manifests_path text null,
  checksum_sha256 text null,
  counts_json jsonb not null default '{}'::jsonb,
  loaded_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists tenant_addresses (
  tenant_id uuid primary key references tenants(id) on delete cascade,
  city text null,
  district text null,
  neighborhood text null,
  street text null,
  building_no text null,
  door_no text null,
  address_line text null,
  lat double precision null,
  lng double precision null,
  updated_by_user_id uuid null references users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


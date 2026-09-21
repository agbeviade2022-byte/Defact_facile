-- DEFACT FACILE migration: 003_organizations
-- Multi-user tenant (company).


create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  slug citext not null unique,
  name text not null,
  legal_name text,
  phone text,
  email citext,
  address text,
  city text,
  country_code char(2) not null default 'CI',
  currency char(3) not null default 'XOF',
  ncc text,
  rccm text,
  tax_identifiers jsonb not null default '{}'::jsonb,
  logo_url text,
  default_tax_rate numeric(5,2) not null default 0,
  settings jsonb not null default '{}'::jsonb,
  status text not null default 'ACTIVE' check (status in ('ACTIVE', 'SUSPENDED', 'ARCHIVED')),
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_organizations_updated_at
  before update on public.organizations
  for each row execute function public.set_updated_at();

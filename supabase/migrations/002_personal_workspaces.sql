-- DEFACT FACILE migration: 002_personal_workspaces
-- Solo workspace owned by exactly one user.


create table public.personal_workspaces (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.users(id) on delete cascade,
  display_name text not null,
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
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_personal_workspaces_updated_at
  before update on public.personal_workspaces
  for each row execute function public.set_updated_at();

-- DEFACT FACILE migration: 033_plans
-- Subscription plans.


create table public.plans (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  audience text not null default 'BOTH' check (audience in ('PERSONAL', 'ORGANIZATION', 'BOTH')),
  price_monthly numeric(12,2) not null default 0,
  price_yearly numeric(12,2) not null default 0,
  currency char(3) not null default 'XOF',
  ai_credits_monthly integer not null default 0,
  limits jsonb not null default '{}'::jsonb,
  features jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_plans_updated_at
  before update on public.plans
  for each row execute function public.set_updated_at();

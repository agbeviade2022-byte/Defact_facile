-- DEFACT FACILE migration: 034_subscriptions
-- Workspace subscription state.


create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  personal_workspace_id uuid references public.personal_workspaces(id) on delete restrict,
  organization_id uuid references public.organizations(id) on delete restrict,
  plan_id uuid not null references public.plans(id) on delete restrict,
  status text not null default 'TRIALING' check (status in ('TRIALING', 'ACTIVE', 'PAST_DUE', 'CANCELLED', 'EXPIRED')),
  billing_cycle text not null default 'MONTHLY' check (billing_cycle in ('MONTHLY', 'YEARLY')),
  trial_ends_at timestamptz,
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancelled_at timestamptz,
  payment_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint subscriptions_single_tenant check (
    (personal_workspace_id is not null and organization_id is null) or
    (personal_workspace_id is null and organization_id is not null)
  )
);

create unique index subscriptions_ws_unique on public.subscriptions(personal_workspace_id) where personal_workspace_id is not null;
create unique index subscriptions_org_unique on public.subscriptions(organization_id) where organization_id is not null;

create trigger set_subscriptions_updated_at
  before update on public.subscriptions
  for each row execute function public.set_updated_at();

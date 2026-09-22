-- DEFACT FACILE migration: 029_ai_credits
-- AI credit balances per workspace + configurable action costs.


create table public.ai_credits (
  id uuid primary key default gen_random_uuid(),
  personal_workspace_id uuid references public.personal_workspaces(id) on delete restrict,
  organization_id uuid references public.organizations(id) on delete restrict,
  balance integer not null default 0 check (balance >= 0),
  monthly_allowance integer not null default 0,
  period_start date,
  period_end date,
  updated_at timestamptz not null default now(),
  constraint ai_credits_single_tenant check (
    (personal_workspace_id is not null and organization_id is null) or
    (personal_workspace_id is null and organization_id is not null)
  )
);

create unique index ai_credits_ws_unique on public.ai_credits(personal_workspace_id) where personal_workspace_id is not null;
create unique index ai_credits_org_unique on public.ai_credits(organization_id) where organization_id is not null;

-- Cost per AI action. Editable without redeploying.
create table public.ai_action_costs (
  action text primary key,
  credits integer not null check (credits >= 0),
  description text,
  updated_at timestamptz not null default now()
);

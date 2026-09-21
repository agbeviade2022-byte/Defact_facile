-- DEFACT FACILE migration: 039_ai_billing
-- User wallets, strict AI reservations, payments, and provider cost tracking.


alter table public.plans
  add column if not exists ai_budget_xof numeric(12,2) not null default 0,
  add column if not exists platform_share_xof numeric(12,2) not null default 0,
  add column if not exists token_multiplier integer not null default 10
    check (token_multiplier > 0);

update public.plans set
  ai_budget_xof = case code
    when 'FREE' then 0
    when 'PERSONAL' then 1000
    when 'BUSINESS_STARTER' then 3500
    when 'BUSINESS' then 6000
    when 'BUSINESS_PRO' then 10000
    else ai_budget_xof end,
  platform_share_xof = case code
    when 'FREE' then 0
    when 'PERSONAL' then 500
    when 'BUSINESS_STARTER' then 4000
    when 'BUSINESS' then 9000
    when 'BUSINESS_PRO' then 20000
    else platform_share_xof end,
  token_multiplier = 10
 where code in ('FREE', 'PERSONAL', 'BUSINESS_STARTER', 'BUSINESS', 'BUSINESS_PRO');

-- The free bonus is account-scoped, never workspace/device/session-scoped.
alter table public.users
  add column if not exists free_ai_bonus_granted_at timestamptz;

create table public.ai_wallets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.users(id) on delete restrict,
  balance integer not null default 0 check (balance >= 0),
  lifetime_credited integer not null default 0 check (lifetime_credited >= 0),
  lifetime_consumed integer not null default 0 check (lifetime_consumed >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_ai_wallets_updated_at
  before update on public.ai_wallets
  for each row execute function public.set_updated_at();

create table public.ai_wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references public.ai_wallets(id) on delete restrict,
  user_id uuid not null references public.users(id) on delete restrict,
  kind text not null check (kind in ('FREE_BONUS', 'PLAN_GRANT', 'TOP_UP', 'RESERVATION', 'CONSUMPTION', 'REFUND', 'EXPIRATION', 'ADJUSTMENT')),
  amount integer not null check (amount <> 0 or kind = 'CONSUMPTION'),
  idempotency_key text unique,
  provider text,
  provider_reference text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index ai_wallet_transactions_user_created_idx
  on public.ai_wallet_transactions(user_id, created_at desc);

create trigger forbid_ai_wallet_transaction_mutation
  before update or delete on public.ai_wallet_transactions
  for each row execute function public.forbid_mutation();

create table public.ai_reservations (
  id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references public.ai_wallets(id) on delete restrict,
  user_id uuid not null references public.users(id) on delete restrict,
  amount integer not null check (amount > 0),
  status text not null default 'RESERVED' check (status in ('RESERVED', 'COMMITTED', 'REFUNDED', 'EXPIRED')),
  provider text,
  action text not null,
  idempotency_key text not null unique,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create index ai_reservations_user_status_idx
  on public.ai_reservations(user_id, status);

create table public.billing_payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete restrict,
  subscription_id uuid references public.subscriptions(id) on delete restrict,
  amount numeric(12,2) not null check (amount > 0),
  currency char(3) not null default 'XOF',
  provider text not null default 'GENIUSPAY',
  provider_reference text not null,
  status text not null default 'PENDING' check (status in ('PENDING', 'SUCCEEDED', 'FAILED', 'CANCELLED')),
  kind text not null check (kind in ('SUBSCRIPTION', 'AI_TOP_UP')),
  metadata jsonb not null default '{}'::jsonb,
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, provider_reference)
);

create trigger set_payments_updated_at
  before update on public.billing_payments
  for each row execute function public.set_updated_at();

create table public.ai_provider_usage (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete restrict,
  reservation_id uuid references public.ai_reservations(id) on delete restrict,
  provider text not null check (provider in ('CLAUDE', 'OPENAI')),
  model text not null,
  input_tokens integer not null default 0 check (input_tokens >= 0),
  output_tokens integer not null default 0 check (output_tokens >= 0),
  cost_xof numeric(12,4) not null default 0 check (cost_xof >= 0),
  succeeded boolean not null,
  created_at timestamptz not null default now()
);

create index ai_provider_usage_user_created_idx
  on public.ai_provider_usage(user_id, created_at desc);

alter table public.ai_wallets enable row level security;
create policy ai_wallets_self_select on public.ai_wallets
  for select using (user_id = auth.uid());

alter table public.ai_wallet_transactions enable row level security;
create policy ai_wallet_transactions_self_select on public.ai_wallet_transactions
  for select using (user_id = auth.uid());

alter table public.ai_reservations enable row level security;
create policy ai_reservations_self_select on public.ai_reservations
  for select using (user_id = auth.uid());

alter table public.billing_payments enable row level security;
create policy billing_payments_self_select on public.billing_payments
  for select using (user_id = auth.uid());

alter table public.ai_provider_usage enable row level security;
create policy ai_provider_usage_self_select on public.ai_provider_usage
  for select using (user_id = auth.uid());

-- Wallet writes are atomic and account-scoped. Callers must use the backend.
create or replace function public.grant_free_ai_bonus(p_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet_id uuid;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'AI wallet operations require the backend';
  end if;

  update public.users
     set free_ai_bonus_granted_at = coalesce(free_ai_bonus_granted_at, now())
   where id = p_user_id and free_ai_bonus_granted_at is null;

  if not found then
    select id into v_wallet_id from public.ai_wallets where user_id = p_user_id;
    return v_wallet_id;
  end if;

  insert into public.ai_wallets (user_id, balance, lifetime_credited)
  values (p_user_id, 500, 500)
  on conflict (user_id) do update
    set balance = public.ai_wallets.balance + 500,
        lifetime_credited = public.ai_wallets.lifetime_credited + 500
  returning id into v_wallet_id;

  insert into public.ai_wallet_transactions
    (wallet_id, user_id, kind, amount, idempotency_key)
  values
    (v_wallet_id, p_user_id, 'FREE_BONUS', 500, 'free-bonus:' || p_user_id)
  on conflict (idempotency_key) do nothing;

  return v_wallet_id;
end;
$$;

create or replace function public.reserve_ai_tokens(
  p_user_id uuid,
  p_amount integer,
  p_action text,
  p_provider text,
  p_idempotency_key text,
  p_expires_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet_id uuid;
  v_reservation_id uuid;
  v_existing_user_id uuid;
  v_existing_amount integer;
  v_existing_action text;
  v_existing_provider text;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'AI wallet operations require the backend';
  end if;

  if p_amount <= 0 then raise exception 'AI reservation amount must be positive'; end if;

  select id into v_wallet_id
    from public.ai_wallets
   where user_id = p_user_id
   for update;
  if v_wallet_id is null then raise exception 'AI wallet not found'; end if;

  select id, user_id, amount, action, provider
    into v_reservation_id, v_existing_user_id, v_existing_amount,
         v_existing_action, v_existing_provider
    from public.ai_reservations
   where idempotency_key = p_idempotency_key;
  if v_reservation_id is not null then
    if v_existing_user_id <> p_user_id
       or v_existing_amount <> p_amount
       or v_existing_action <> p_action
       or v_existing_provider <> p_provider then
      raise exception 'AI reservation idempotency key reuse conflict';
    end if;
    return v_reservation_id;
  end if;

  update public.ai_wallets
     set balance = balance - p_amount
   where id = v_wallet_id and balance >= p_amount;
  if not found then raise exception 'AI quota insufficient'; end if;

  insert into public.ai_reservations
    (wallet_id, user_id, amount, provider, action, idempotency_key, expires_at)
  values
    (v_wallet_id, p_user_id, p_amount, p_provider, p_action, p_idempotency_key, p_expires_at)
  returning id into v_reservation_id;

  insert into public.ai_wallet_transactions
    (wallet_id, user_id, kind, amount, idempotency_key, provider)
  values
    (v_wallet_id, p_user_id, 'RESERVATION', -p_amount, 'reservation:' || p_idempotency_key, p_provider);

  return v_reservation_id;
end;
$$;

create or replace function public.complete_ai_reservation(p_reservation_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet_id uuid;
  v_user_id uuid;
  v_amount integer;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'AI wallet operations require the backend';
  end if;

  update public.ai_reservations
     set status = 'COMMITTED', completed_at = now()
   where id = p_reservation_id
     and status = 'RESERVED'
     and expires_at > now()
   returning wallet_id, user_id, amount into v_wallet_id, v_user_id, v_amount;
  if found then
    update public.ai_wallets
       set lifetime_consumed = lifetime_consumed + v_amount
     where id = v_wallet_id;
    insert into public.ai_wallet_transactions
      (wallet_id, user_id, kind, amount, idempotency_key)
    values
      (v_wallet_id, v_user_id, 'CONSUMPTION', 0, 'consumption:' || p_reservation_id)
    on conflict (idempotency_key) do nothing;
    return true;
  end if;
  return false;
end;
$$;

create or replace function public.refund_ai_reservation(p_reservation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet_id uuid;
  v_user_id uuid;
  v_amount integer;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'AI wallet operations require the backend';
  end if;

  update public.ai_reservations
     set status = 'REFUNDED', completed_at = now()
   where id = p_reservation_id and status = 'RESERVED'
   returning wallet_id, user_id, amount into v_wallet_id, v_user_id, v_amount;
  if found then
    update public.ai_wallets
       set balance = balance + v_amount
     where id = v_wallet_id;
    insert into public.ai_wallet_transactions
      (wallet_id, user_id, kind, amount, idempotency_key)
    values
      (v_wallet_id, v_user_id, 'REFUND', v_amount, 'refund:' || p_reservation_id)
    on conflict (idempotency_key) do nothing;
  end if;
end;
$$;

create or replace function public.expire_ai_reservation(p_reservation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet_id uuid;
  v_user_id uuid;
  v_amount integer;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'AI wallet operations require the backend';
  end if;

  update public.ai_reservations
     set status = 'EXPIRED', completed_at = now()
   where id = p_reservation_id
     and status = 'RESERVED'
     and expires_at <= now()
   returning wallet_id, user_id, amount into v_wallet_id, v_user_id, v_amount;

  if found then
    update public.ai_wallets
       set balance = balance + v_amount
     where id = v_wallet_id;
    insert into public.ai_wallet_transactions
      (wallet_id, user_id, kind, amount, idempotency_key)
    values
      (v_wallet_id, v_user_id, 'EXPIRATION', v_amount, 'expiration:' || p_reservation_id)
    on conflict (idempotency_key) do nothing;
  end if;
end;
$$;

create or replace function public.expire_ai_reservations()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reservation_id uuid;
  v_count integer := 0;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'AI wallet operations require the backend';
  end if;

  for v_reservation_id in
    select id
      from public.ai_reservations
     where status = 'RESERVED' and expires_at <= now()
     for update skip locked
  loop
    perform public.expire_ai_reservation(v_reservation_id);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

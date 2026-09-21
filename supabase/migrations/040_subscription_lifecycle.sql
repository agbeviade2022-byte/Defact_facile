-- DEFACT FACILE migration: 040_subscription_lifecycle
-- Atomic subscription activation and expiration helpers.


create or replace function public.activate_subscription(
  p_subscription_id uuid,
  p_user_id uuid,
  p_payment_reference text,
  p_period_start timestamptz,
  p_period_end timestamptz
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plan_id uuid;
  v_grant_amount integer;
  v_wallet_id uuid;
  v_activated boolean;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'Subscription lifecycle operations require the backend';
  end if;

  select plan_id into v_plan_id
    from public.subscriptions
   where id = p_subscription_id;
  select ai_credits_monthly into v_grant_amount
    from public.plans
   where id = v_plan_id;

  update public.subscriptions
     set status = 'ACTIVE',
         payment_reference = p_payment_reference,
         current_period_start = p_period_start,
         current_period_end = p_period_end,
         cancelled_at = null
   where id = p_subscription_id
     and status in ('TRIALING', 'PAST_DUE', 'ACTIVE')
     and (status <> 'ACTIVE' or current_period_end is null or current_period_end <= p_period_start);
  v_activated := found;
  if v_activated and coalesce(v_grant_amount, 0) > 0 then
    insert into public.ai_wallets (user_id)
    values (p_user_id)
    on conflict (user_id) do update set updated_at = now()
    returning id into v_wallet_id;

    insert into public.ai_wallet_transactions
      (wallet_id, user_id, kind, amount, idempotency_key, provider_reference, metadata)
    values
      (v_wallet_id, p_user_id, 'PLAN_GRANT', v_grant_amount,
       'plan:' || p_subscription_id || ':' || p_period_start,
       p_payment_reference,
       jsonb_build_object('subscription_id', p_subscription_id, 'period_end', p_period_end))
    on conflict (idempotency_key) do nothing;

    if found then
      update public.ai_wallets
         set balance = balance + v_grant_amount,
             lifetime_credited = lifetime_credited + v_grant_amount
       where id = v_wallet_id;
    end if;
  end if;
  return v_activated;
end;
$$;

create or replace function public.expire_due_subscriptions()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'Subscription lifecycle operations require the backend';
  end if;

  update public.subscriptions
     set status = 'EXPIRED'
   where status in ('TRIALING', 'ACTIVE', 'PAST_DUE')
     and (
       (current_period_end is not null and current_period_end <= now())
       or (current_period_end is null and trial_ends_at is not null and trial_ends_at <= now())
     );
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.credit_ai_top_up(
  p_user_id uuid,
  p_amount integer,
  p_provider text,
  p_provider_reference text,
  p_idempotency_key text
)
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
  if p_amount <= 0 then
    raise exception 'AI top-up amount must be positive';
  end if;

  insert into public.ai_wallets (user_id)
  values (p_user_id)
  on conflict (user_id) do nothing
  returning id into v_wallet_id;

  if v_wallet_id is null then
    select id into v_wallet_id from public.ai_wallets where user_id = p_user_id for update;
  end if;

  insert into public.ai_wallet_transactions
    (wallet_id, user_id, kind, amount, idempotency_key, provider, provider_reference)
  values
    (v_wallet_id, p_user_id, 'TOP_UP', p_amount, p_idempotency_key, p_provider, p_provider_reference)
  on conflict (idempotency_key) do nothing;

  if found then
    update public.ai_wallets
       set balance = balance + p_amount,
           lifetime_credited = lifetime_credited + p_amount
     where id = v_wallet_id;
  end if;
  return v_wallet_id;
end;
$$;

create unique index if not exists billing_pending_subscription_unique
  on public.billing_payments(subscription_id)
  where kind = 'SUBSCRIPTION' and status = 'PENDING';

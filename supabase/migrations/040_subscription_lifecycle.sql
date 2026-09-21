-- DEFACT FACILE migration: 040_subscription_lifecycle
-- Atomic subscription activation and expiration helpers.


create or replace function public.activate_subscription(
  p_subscription_id uuid,
  p_payment_reference text,
  p_period_start timestamptz,
  p_period_end timestamptz
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'Subscription lifecycle operations require the backend';
  end if;

  update public.subscriptions
     set status = 'ACTIVE',
         payment_reference = p_payment_reference,
         current_period_start = p_period_start,
         current_period_end = p_period_end,
         cancelled_at = null
   where id = p_subscription_id
     and status in ('TRIALING', 'PAST_DUE', 'ACTIVE')
     and (status <> 'ACTIVE' or current_period_end is null or current_period_end <= p_period_start);
  return found;
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

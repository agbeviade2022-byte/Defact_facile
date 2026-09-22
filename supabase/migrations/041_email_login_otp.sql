-- DEFACT FACILE migration: 041_email_login_otp
-- Server-managed one-time codes for passwordless email sign-in.

create table public.email_login_otps (
  id uuid primary key default gen_random_uuid(),
  email citext not null,
  code_hash text not null,
  expires_at timestamptz not null,
  attempts smallint not null default 0 check (attempts >= 0 and attempts <= 5),
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);

create index email_login_otps_email_created_idx
  on public.email_login_otps (email, created_at desc);

alter table public.email_login_otps enable row level security;

create or replace function public.consume_email_login_otp(
  p_email citext,
  p_code_hash text
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_otp public.email_login_otps%rowtype;
begin
  select *
    into v_otp
    from public.email_login_otps
   where email = lower(p_email)
     and consumed_at is null
   order by created_at desc
   limit 1
   for update;

  if not found then
    return 'not_found';
  end if;

  if v_otp.expires_at <= now() then
    return 'expired';
  end if;

  if v_otp.attempts >= 5 then
    return 'too_many_attempts';
  end if;

  update public.email_login_otps
     set attempts = attempts + 1
   where id = v_otp.id;

  if v_otp.code_hash <> p_code_hash then
    return 'invalid';
  end if;

  update public.email_login_otps
     set consumed_at = now()
   where id = v_otp.id;

  return 'verified';
end;
$$;

revoke all on function public.consume_email_login_otp(citext, text) from public;

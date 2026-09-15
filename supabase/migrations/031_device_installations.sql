-- DEFACT FACILE migration: 031_device_installations
-- App installations (anti-abuse signal, never the sole blocking criterion).


create table public.device_installations (
  id uuid primary key default gen_random_uuid(),
  installation_id text not null unique,
  user_id uuid references public.users(id) on delete set null,
  platform text check (platform in ('android', 'ios', 'web')),
  app_version text,
  device_model text,
  os_version text,
  first_ip inet,
  last_ip inet,
  push_token text,
  trial_started_at timestamptz,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create index device_installations_user_idx on public.device_installations(user_id);

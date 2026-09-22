-- DEFACT FACILE migration: 005_permissions
-- Granular permission catalogue (resource.action).


create table public.permissions (
  code text primary key,
  resource text not null,
  action text not null,
  description text,
  constraint permissions_code_format check (code = resource || '.' || action)
);

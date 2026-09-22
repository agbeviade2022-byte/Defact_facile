-- DEFACT FACILE migration: 006_role_permissions
-- Role -> permission mapping.


create table public.role_permissions (
  role_id uuid not null references public.roles(id) on delete cascade,
  permission_code text not null references public.permissions(code) on delete cascade,
  primary key (role_id, permission_code)
);

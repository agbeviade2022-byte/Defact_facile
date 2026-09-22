# Supabase

- `migrations/` : 38 migrations numérotées, à appliquer dans l'ordre (`supabase db push` ou `psql -f`).
- `scripts/validate_migrations.sh` : rejoue toutes les migrations sur un PostgreSQL jetable (CI / local).
  Il applique d'abord `scripts/local_shim.sql` qui imite `auth.users`, `auth.uid()`, `auth.role()` et les rôles
  `anon` / `authenticated` / `service_role`. **Ne jamais appliquer le shim sur un vrai projet Supabase.**
- Un projet Supabase distinct par environnement (development, staging, production). Auth (OTP e-mail, Google) et
  Storage se configurent dans le dashboard de chaque projet.

Conventions de schéma : voir `docs/database.md` et `docs/mission-01-foundation.md`.

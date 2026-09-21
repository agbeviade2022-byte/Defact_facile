#!/usr/bin/env bash
# Applies every migration in order against a throwaway PostgreSQL database.
# Usage: DATABASE_URL=postgres://... supabase/scripts/validate_migrations.sh
set -euo pipefail
cd "$(dirname "$0")/.."
: "${DATABASE_URL:?DATABASE_URL is required}"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f scripts/local_shim.sql
for f in $(ls migrations/*.sql | sort); do
  echo "→ $f"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f "$f"
done
echo "All migrations applied successfully."

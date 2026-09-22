# Mission 01 — Foundation

## 1. Analyse du repository fourni

Le package `DEFACT_FACILE_FULL_PACKAGE.zip` contenait une spécification complète (`docs/`, `ui-ux/`) mais un code
squelette uniquement : dossiers vides, READMEs d'une ligne et 38 fichiers de migration ne contenant qu'un `-- TODO`.
Aucune application Flutter, aucun projet NestJS, aucun schéma SQL, aucune CI.

Problèmes détectés :

- `nestjs-pino` et `@nestjs/config@latest` exigent NestJS 11/12 → version épinglées compatibles NestJS 10
  (`@nestjs/config@3`, `@nestjs/throttler@6`, `@nestjs/terminus@10`, `@nestjs/swagger@8`). Logging : `Logger` Nest natif.
- Le package prévoyait un fichier `.env` côté Flutter : remplacé par `--dart-define-from-file` (aucun secret embarqué,
  aucune lecture de fichier au runtime).
- Aucune contradiction d'architecture avec le cahier des charges ; la structure fournie a été conservée.

## 2. Architecture mise en place

### Backend (`backend/`)

```
src/
  main.ts                 prefix /api/v1, Helmet, CORS, ValidationPipe (whitelist + forbidNonWhitelisted), Swagger (hors prod)
  app.module.ts           Config global, Supabase global, Throttler (APP_GUARD), HttpExceptionFilter (APP_FILTER), Health, 28 modules métier
  config/                 env.schema.ts (Zod, échec au démarrage), AppConfigService typé, ConfigModule (.env.<NODE_ENV> puis .env)
  supabase/               SupabaseService : client admin (service_role, serveur uniquement) + forUser(token) soumis à RLS
  common/
    constants/            SYSTEM_ROLES (9), PERMISSIONS (44) — source de vérité alignée sur 038_seed_data.sql
    decorators/           @Public(), @RequirePermissions(...)
    filters/              enveloppe d'erreur normalisée {statusCode, error, message, path, timestamp, details?}
    types/                AuthenticatedUser, WorkspaceContext, RequestContext
  health/                 GET /api/v1/health (mémoire + requête Supabase)
  auth/ users/ organizations/ memberships/ roles/ permissions/ customers/ products/ quotes/ invoices/ sales/ payments/
  inventory/ expenses/ suppliers/ purchases/ deliveries/ reports/ stores/ cash_register/ ai/ whatsapp/ fne/ pdf/
  notifications/ subscriptions/ anti_abuse/ audit/     modules Nest explicites, vides, un par responsabilité
```

Tests : `env.schema.spec.ts` (4 tests unitaires), `test/health.e2e-spec.ts` (2 tests e2e, Supabase stubbé).

### Mobile (`mobile/flutter_app/`)

```
lib/
  main.dart / app.dart          ProviderScope → MaterialApp.router (thème + routeur)
  core/config/app_config.dart   valeurs publiques via String.fromEnvironment (APP_ENV, API_BASE_URL, SUPABASE_URL, SUPABASE_ANON_KEY)
  core/theme/                   AppColors, AppTypography (Inter), AppSpacing (4→64, touch 48), AppRadius (6→pill), AppShadows, AppTheme.light()
  core/router/                  AppRoutes, buildRouter() (go_router), WorkspaceShell adaptatif (NavigationBar < 840px, NavigationRail au-delà)
  core/network/api_client.dart  Dio + intercepteur Bearer / X-Workspace-Id, ApiException alignée sur l'enveloppe backend
  shared/widgets/               AppLoadingState, AppEmptyState, AppErrorState, AppOfflineState, AppPermissionDeniedState, PlaceholderScreen
  features/<feature>/presentation/   splash, auth (login layout), workspaces (sélecteur)
env/development.json | staging.json | production.json
```

Deux shells de navigation conformes à `ui-ux/03-navigation` : personnel (Accueil/Devis/Factures/Clients/Plus) et
entreprise (Accueil/Ventes/Factures/Stock/Clients/Plus). Les écrans métier sont des `PlaceholderScreen` explicitement
marqués avec la mission qui les implémentera.

Tests : 5 tests widget/unit (rendu login, shell 5 onglets + changement de branche, rail sur écran large, route
inconnue, tokens du thème).

### Base de données (`supabase/migrations/001…038`)

36 tables, toutes avec RLS activé, 35 policies, 9 rôles, 44 permissions, 4 plans.

Décisions de schéma :

- Multi-tenant : chaque table métier porte `personal_workspace_id` **ou** `organization_id` (contrainte XOR).
  `public.can_access_tenant(pw, org)` centralise la vérification RLS. Le contrôle fin par permission (`role_permissions`)
  est appliqué côté API (`@RequirePermissions`) ; un helper SQL `has_permission` pourra compléter RLS en Mission 03.
- `public.users` est créé automatiquement depuis `auth.users` (trigger) → un seul compte global.
- Devis/factures/ventes : pas de `DELETE`, statuts `cancelled`/`void`, numérotation par tenant.
- Stock : `stock_movements` append-only (trigger interdit UPDATE/DELETE), `stock_levels` recalculés par trigger.
- `audit_logs` immuable. `updated_at` géré par trigger partout.
- `supabase/scripts/validate_migrations.sh` + `local_shim.sql` permettent de rejouer les 38 migrations sur un PostgreSQL nu
  (utilisé par la CI). Le shim ne doit jamais être appliqué sur Supabase.

### CI (`.github/workflows/ci.yml`)

4 jobs : backend (format, lint, typecheck, unit, e2e, build, `npm audit --audit-level=high`), mobile (format, analyze
`--fatal-infos`, test, build web), database (38 migrations sur postgres:15 + échec si une table publique est sans RLS),
secrets-scan (gitleaks).

## 3. Vérifications effectuées

| Vérification | Résultat |
|---|---|
| `npm run lint` / `format:check` / `typecheck` | OK |
| `npm test` | 4 passed |
| `npm run test:e2e` | 2 passed |
| `npm run build` | OK |
| `flutter analyze --fatal-infos` | No issues found |
| `flutter test` | 5 passed |
| `flutter build web --dart-define-from-file=env/development.json` | OK |
| 38 migrations sur PostgreSQL 14 | All migrations applied successfully ; 36/36 tables avec RLS |

## 4. Problèmes restants / limites connues

- Les migrations sont validées sur PostgreSQL nu avec un shim `auth.*` ; une validation sur un vrai projet Supabase
  (Auth activé, Storage) reste à faire lors de la configuration des projets dev/staging/prod.
- Aucun projet Supabase, aucune clé Resend/Anthropic/OpenAI n'est configuré : les `.env` sont à renseigner.
- Le build Android/iOS n'a pas été exécuté (SDK absents sur la machine de build) ; le build web l'a été.
- Le logger structuré (pino) est reporté à une version compatible NestJS 10 ou à une montée en NestJS 11.
- Les écrans login / sélecteur d'espace sont des layouts : aucune authentification n'est câblée (Mission 02).

## 5. Prochaine étape

Mission 02 — Authentification (OTP e-mail + Google via Supabase Auth, guard JWT côté API, résolution du contexte
workspace). Ne pas démarrer avant validation de cette fondation.

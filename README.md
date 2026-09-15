# DEFACT FACILE

**Devis. Factures. Gestion. Facile.**

Plateforme SaaS de devis, facturation et gestion commerciale (indépendants, artisans, commerçants, PME) avec IA native.
Lire d'abord : `docs/cahier-des-charges.md`, puis `docs/architecture.md`.

## Monorepo

| Dossier | Contenu | Stack |
|---|---|---|
| `mobile/flutter_app` | Application mobile / web (feature-first) | Flutter 3.x, Riverpod, go_router, Dio |
| `backend` | API REST `/api/v1` | NestJS 10, TypeScript strict, Zod, Supabase JS |
| `supabase` | Migrations SQL numérotées, RLS, seed | PostgreSQL / Supabase |
| `ai` | Prompts, tools, guardrails (à venir) | Claude (principal), OpenAI (secours) |
| `integrations` | Adapters Resend, WhatsApp, FNE, PDF | — |
| `docs`, `ui-ux` | Spécification produit et design system | — |
| `.github/workflows` | CI (backend, mobile, base de données, secrets) | GitHub Actions |

## Prérequis

- Node.js 20 + npm
- Flutter 3.35+ (Dart 3.9+)
- PostgreSQL 14+ (`psql`) pour valider les migrations en local, ou Supabase CLI

## Démarrage rapide

```bash
# Backend
cd backend
cp .env.example .env.development   # renseigner les valeurs
npm ci
npm run start:dev                  # http://localhost:3000/api/v1/health — Swagger: /docs

# Mobile
cd mobile/flutter_app
flutter pub get
flutter run --dart-define-from-file=env/development.json
# Émulateur Android (localhost = l'émulateur) : env/development.android.json (10.0.2.2) ; appareil physique : remplacer par l'IP LAN du poste

# Base de données (PostgreSQL local jetable)
DATABASE_URL=postgres://postgres:postgres@localhost:5432/defact_test \
  supabase/scripts/validate_migrations.sh
```

## Environnements

Trois environnements séparés : **development**, **staging**, **production**. Chacun a son propre projet Supabase,
ses propres clés et son propre déploiement backend.

| Couche | Development | Staging | Production |
|---|---|---|---|
| Backend | `backend/.env.development` | `backend/.env.staging` | `backend/.env.production` |
| Mobile | `env/development.json` | `env/staging.json` | `env/production.json` |
| Supabase | projet dev / local | projet staging | projet prod |

Règles :

- Les fichiers `.env*` réels ne sont **jamais** committés (`.gitignore`). Seuls `.env.example` et `.env.test` le sont.
- Le backend valide ses variables au démarrage (`backend/src/config/env.schema.ts`) et refuse de démarrer si une clé manque.
- Le mobile ne reçoit que des valeurs publiques via `--dart-define-from-file` (`API_BASE_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`).
  La clé `service_role`, Resend, Anthropic, OpenAI, FNE ne quittent jamais le backend.
- `NODE_ENV=production` désactive Swagger, active les en-têtes de sécurité stricts et **refuse `CORS_ORIGINS=*`** (liste explicite obligatoire).

## Commandes de vérification

```bash
# Backend
cd backend && npm run format:check && npm run lint && npm run typecheck && npm test && npm run test:e2e && npm run build

# Mobile
cd mobile/flutter_app && dart format --set-exit-if-changed lib test && flutter analyze --fatal-infos && flutter test && flutter build web

# Base de données
DATABASE_URL=... supabase/scripts/validate_migrations.sh
```

La CI (`.github/workflows/ci.yml`) exécute exactement ces étapes, plus : audit npm, vérification que toutes les tables
`public` ont RLS activé, et scan de secrets (gitleaks).

## Principes non négociables

- Flutter n'est **jamais** une frontière de sécurité : auth, tenant, permissions et règles métier sont validés par l'API et par RLS.
- Un seul compte utilisateur global ; espace personnel + N organisations avec rôles différents.
- Calculs financiers déterministes côté backend, jamais par un LLM.
- Toute mutation IA passe par un aperçu et une confirmation explicite.
- Les documents financiers ne sont pas supprimés physiquement (annulation / archivage + audit).
- Les mouvements de stock sont des événements immuables ; les niveaux sont dérivés.
- FNE : architecture d'adaptateur uniquement, aucune certification revendiquée.

## Feuille de route

Voir `docs/roadmap.md`. État actuel : **Mission 01 — Foundation** (voir `docs/mission-01-foundation.md`).

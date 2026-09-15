# CAHIER DES CHARGES — DEFACT FACILE

**Version : 1.0 — Septembre 2026**

## 1. Présentation
DEFACT FACILE est une plateforme mobile et web de devis, facturation et gestion commerciale destinée aux indépendants, artisans, freelances, commerçants et PME, avec une couche d'intelligence artificielle native.

**Signature :** Devis. Factures. Gestion. Facile.

## 2. Objectifs
- Simplifier la création de devis et factures.
- Centraliser clients, produits, ventes et paiements.
- Fournir une gestion d'entreprise adaptée aux PME.
- Fonctionner en contexte de connectivité variable grâce à une approche offline-first.
- Intégrer les moyens de paiement courants du marché cible.
- Préparer l'intégration à la facturation électronique FNE en Côte d'Ivoire.
- Ajouter l'IA pour assister, analyser et automatiser certaines opérations, sans lui confier l'autorité métier ou financière.

## 3. Public cible
### Espace Personnel
Indépendants, artisans, consultants, développeurs, prestataires, freelances et micro-entrepreneurs.

### Espace Entreprise
PME et organisations ayant plusieurs collaborateurs, rôles, boutiques, entrepôts ou caisses.

## 4. Principe d'identité
Un seul compte utilisateur peut posséder un espace personnel et appartenir à plusieurs organisations.
Exemple:
- David → espace personnel
- David → Glo'Nature → Administrateur
- David → Entreprise B → Commercial

L'organisation et le rôle sont déterminés par la membership, pas par un compte séparé.

## 5. Fonctionnalités principales
### Authentification
- Email + OTP.
- Google OAuth.
- Gestion de session.
- Déconnexion.
- Téléphone optionnel en V1.

### Workspace
- Création d'espace personnel.
- Création d'entreprise.
- Invitation de membres.
- Changement d'espace sans déconnexion.
- Isolation stricte des données.

### Clients
- CRUD.
- Coordonnées.
- Historique devis/factures/paiements.
- Créances.
- Recherche.

### Produits / services
- CRUD.
- Prix d'achat et de vente.
- SKU/barcode.
- Unité.
- Catégorie.
- Suivi de stock optionnel.

### Devis
- Création/modification.
- Lignes de devis.
- Remise.
- Taxes.
- Conditions.
- Statuts.
- PDF.
- Envoi.
- Conversion en facture.

### Factures
- Création/modification.
- Lignes.
- Remise.
- Taxes.
- Échéance.
- Paiements partiels.
- Statuts.
- PDF.
- Annulation contrôlée.
- Suivi des impayés.

### Paiements
Méthodes configurables incluant:
- Espèces.
- Orange Money.
- MTN MoMo.
- Moov Money.
- Wave.
- Virement.
- Carte.
- Autre.

### Ventes
- Vente rapide.
- Lignes.
- Paiement.
- Mise à jour du stock.

### Stock
- Entrepôts.
- Niveaux de stock.
- Stock minimum.
- Mouvements.
- Entrées/sorties.
- Transferts.
- Retours.
- Alertes.

### Achats / fournisseurs
- Fournisseurs.
- Commandes d'achat.
- Réception.
- Entrée stock.
- Paiement.

### Caisse
- Caisses par boutique.
- Solde.
- Encaissements.
- Décaissements.
- Dépôts/retraits.
- Ajustements.

### Dépenses
- Catégorie.
- Montant.
- Date.
- Mode de paiement.
- Justificatif ultérieur.

### Livraisons
- Préparation.
- En livraison.
- Livrée.
- Échec.
- Retour.

### Rapports
- CA.
- Ventes.
- Dépenses.
- Paiements.
- Créances.
- Stock.
- Rentabilité estimée.
- Périodes configurables.

### Équipe / permissions
Rôles système:
OWNER, ADMIN, MANAGER, ACCOUNTANT, SALES, STOCK_MANAGER, CASHIER, DELIVERY, VIEWER.
Possibilité de créer des rôles personnalisés.

### WhatsApp
V1:
- génération PDF;
- partage via le mécanisme de partage du téléphone;
- ouverture de WhatsApp lorsque disponible.

V2:
- intégration WhatsApp Business API selon disponibilité et conformité.

### FNE
Prévoir une architecture d'adaptation vers les services officiels FNE.
Ne jamais présenter l'application comme « certifiée FNE » avant obtention des validations/agréments/intégrations nécessaires.

## 6. IA
L'IA est transversale:
- création de devis en langage naturel;
- création de factures;
- questions sur l'activité;
- analyse des ventes;
- analyse du stock;
- analyse des clients;
- détection d'anomalies;
- recommandations;
- OCR de documents;
- voix vers action;
- rédaction de messages.

### Règle d'exécution
Utilisateur → AI Gateway → interprétation → outils backend → aperçu → confirmation → exécution backend.

L'IA ne doit pas écrire directement dans la base.
Les calculs financiers sont déterministes côté backend.
Les permissions backend s'appliquent aussi aux outils IA.
Ne pas envoyer toute la base de données au LLM.

## 7. AI Gateway
Centralise:
- sélection fournisseur;
- modèle;
- quotas;
- crédits;
- logs;
- coûts estimés;
- sécurité;
- anti-abus.

Prévoir des providers interchangeables, notamment Anthropic et OpenAI.

## 8. Crédits IA
Exemple initial configurable:
- question simple: 1
- message: 1
- devis: 2
- facture: 2
- analyse client: 3
- OCR: 5
- analyse stock: 5
- analyse ventes: 5
- rapport financier: 10
- rapport complet: 15

Les tarifs et consommations doivent être configurables sans redéploiement.

## 9. Offline-first
Certaines opérations doivent rester disponibles hors ligne:
- consultation des données mises en cache;
- création locale de documents autorisés;
- file d'attente de synchronisation.

La synchronisation doit gérer:
- version;
- timestamps;
- queue;
- erreurs;
- conflits.

Les mouvements de stock sont traités comme événements et ne doivent pas être gérés par simple écrasement aveugle d'une quantité.

## 10. Sécurité
- HTTPS.
- JWT/session sécurisée.
- RBAC serveur.
- RLS PostgreSQL/Supabase.
- Validation des entrées.
- Rate limiting.
- Secrets uniquement serveur.
- Audit des actions sensibles.
- Isolation multi-tenant.
- Tests d'accès inter-organisation.

Le frontend n'est jamais une frontière de sécurité.

## 11. Modèle de données
Tables principales:
users
personal_workspaces
organizations
roles
permissions
role_permissions
organization_members
customers
product_categories
products
quotes
quote_items
invoices
invoice_items
payments
sales
sale_items
warehouses
stock_levels
stock_movements
stores
cash_registers
cash_transactions
suppliers
purchases
purchase_items
expenses
deliveries
ai_credits
ai_usage
device_installations
anti_abuse_events
plans
subscriptions
audit_logs

## 12. API
Base: `/api/v1/`

Endpoints majeurs:
- `/auth/me`
- `/customers`
- `/products`
- `/quotes`
- `/quotes/:id/send`
- `/quotes/:id/convert-to-invoice`
- `/invoices`
- `/invoices/:id/send`
- `/invoices/:id/cancel`
- `/invoices/:id/payment`
- `/invoices/:id/pdf`
- `/payments`
- `/inventory`
- `/inventory/adjustments`
- `/inventory/transfers`
- `/sales`
- `/expenses`
- `/dashboard`
- `/reports`
- `/ai/chat`
- `/ai/execute`
- `/ai/credits`
- `/ai/usage`

## 13. Workflow commercial
Devis → acceptation → commande → livraison → facture → paiement → reçu.

Stock:
Achat → réception → entrée stock → vente → sortie stock.

## 14. Documents
Formats:
- devis;
- facture;
- reçu;
- proforma;
- avoir selon évolution.

PDF:
- logo;
- identité de l'entreprise;
- identifiants fiscaux;
- client;
- lignes;
- totaux;
- conditions;
- statut;
- éléments FNE lorsque disponibles.

## 15. UX
Design:
- mobile-first;
- français en priorité;
- professionnel;
- simple;
- action principale visible;
- états loading/empty/error/offline/success/permission;
- accessibilité minimale 44–48 px pour les zones tactiles.

Palette:
- Primary #0B6B4F
- Primary Dark #07513C
- Accent #F4B740
- Background #F7F9F8
- Surface #FFFFFF
- Text #14201B
- Secondary #5E6B65
- Success #168A5A
- Warning #D98A00
- Error #D64545

Typographie: Inter.

## 16. Architecture
### Mobile
Flutter + architecture par features.

### Backend
NestJS + TypeScript + REST.

### Base
Supabase PostgreSQL + Auth + Storage + RLS.

### Services
Resend, fournisseurs IA, WhatsApp, FNE selon intégrations disponibles.

## 17. Roadmap
### Phase 1
Fondation, Auth, Workspaces, RBAC, design system.

### Phase 2
Clients, produits, devis, factures, paiements, PDF.

### Phase 3
Ventes, stock, dépenses, caisse, fournisseurs, achats, livraisons.

### Phase 4
Équipe, boutiques, rapports, audit.

### Phase 5
IA, crédits, OCR, voix, analyses.

### Phase 6
WhatsApp avancé, abonnements, anti-abus, offline avancé.

### Phase 7
FNE et production.

## 18. Critères d'acceptation
Une fonctionnalité est considérée terminée uniquement si:
1. UI terminée.
2. API terminée.
3. Validation métier terminée.
4. Permissions vérifiées.
5. Erreurs gérées.
6. États loading/empty/error/offline traités.
7. Tests unitaires/intégration pertinents présents.
8. Journalisation nécessaire présente.
9. Aucun secret exposé.
10. Aucun accès inter-organisation possible.

## 19. Règle de développement pour Devin
Ne pas construire l'application comme une succession d'écrans indépendants.
Toute fonctionnalité doit respecter:
- multi-tenant;
- RBAC;
- sécurité serveur;
- offline-first;
- API;
- règles métier;
- audit;
- IA contrôlée.

L'IA assiste, le backend décide et exécute.

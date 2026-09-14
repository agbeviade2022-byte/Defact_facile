# RÉSUMÉ DES TESTS POSSIBLES - DEFACT FACILE

## Tests recommandés pour vérifier l'implémentation

### 1. Tests de l'AI Gateway
**Objectif:** Vérifier que l'AI Gateway fonctionne correctement avec fallback et gestion des tokens

**Scénarios de test:**
- [ ] Test appel réussi vers Anthropic → crédits débités, réponse renvoyée
- [ ] Test échec Anthropic bascule vers OpenAI → crédits débités seulement auprès du provider qui réussit
- [ ] Test estimation tokens avant appel → réserve correctement débitée
- [ ] Test échec d'appel AI → tokens réservés remboursés au wallet
- [ ] Test logging usage après succès → entrée créée dans ai_usage (via wallet transactions)
- [ ] Test sanitisation des données → aucune donnée sensitive n'est envoyée au LLM

### 2. Tests du Wallet et des Transactions
**Objectif:** Vérifier le système de tokens et les transactions GeniusPay

**Scénarios de test:**
- [ ] Test solde initial wallet → retourne 0 ou valeur configurée
- [ ] Test créditer tokens via méthode directe → solde augmenté correctement
- [ ] Test débiter tokens pour appel AI → solde diminué, transaction créée
- [ ] Test type transaction GENIUSPAY_PAYMENT → correctement enregistré en base
- [ ] Test récupération historique transactions → inclut tous les types avec détails

### 3. Tests de l'intégration GeniusPay
**Objectif:** Vérifier le flux de paiement complet

**Scénarios de test:**
- [ ] Test initialisation paiement abonnement → retourne URL de paiement valide
- [ ] Test initialisation recharge tokens → retourne URL de paiement valide
- [ ] Test webhook GeniusPay valide → crédite wallet du bon montant en tokens
- [ ] Test webhook GeniusPay invalide (signature) → rejeté, aucun crédit
- [ ] Test webhook paiement échoué → aucun crédit wallet
- [ ] Test idempotence webhook → même webhook traité deux fois n'a qu'un effet

### 4. Tests du Frontend Mobile
**Objectif:** Vérifier l'expérience utilisateur et l'intégration des services

**Scénarios de test:**
- [ ] Test dashboard affiche solde wallet → valeur correcte affichée
- [ ] Test bouton "Grant Free Bonus" → augmente solde de 500 tokens
- [ ] Test navigation dashboard → AI chat → fonctionne sans erreur
- [ ] Test AI chat envoie message → reçoit réponse du backend
- [ ] Test états loading pendant appel AI → indicateur visible
- [ ] Test gestion d'erreur API → message d'erreur affiché à l'utilisateur

### 5. Tests d'intégration bout en bout
**Objectif:** Vérifier les flux complets utilisateur

**Scénarios de test:**
- [ ] Flux découverte AI: Utilisateur gagne bonus → discute avec IA → tokens débités
- [ ] Flux paiement: Utilisateur initie recharge → paie via GeniusPay → webhook reçu → tokens crédités
- [ ] Flux fallback IA: Provider primaire échoue → bascule automatique → service continue

### 6. Tests de sécurité
**Objectif:** Vérifier que aucune vulnérabilité évidente n'est présente

**Scénarios de test:**
- [ ] Test credentials exposés → aucune clé API GeniusPay ou IA dans réponses frontend
- [ ] Test autorisation endpoints → endpoints protégés renvoient 401 sans JWT valide
- [ ] Test webhook sécurité → endpoint webhook traite seulement requêtes signées valides
- [ ] Test injection tenté → aucune injection réussie via paramètres API

## Instructions pour exécuter les tests

### Backend (NestJS)
```bash
# Depuis le dossier backend
npm run test          # Tests unitaires
npm run test:e2e      # Tests end-to-end
```

### Mobile (Flutter)
```bash
# Depuis le dossier mobile/flutter_app
flutter test          # Tests unitaires
flutter drive         # Tests d'intégration (nécessite configuration)
```

### Tests manuels rapides
Pour vérifier rapidement que les services répondent:
```bash
# Test santé backend
curl http://localhost:3000/health

# Test documentation API (si activée)
curl http://localhost:3000/api
```

## Critères d'acceptation pour chaque fonctionnalité

Chaque fonctionnalité doit satisfaire:
1. ✅ UI terminée (pour les composants frontend)
2. ✅ API terminée (endpoints fonctionnels)
3. ✅ Validation métier terminée (règles respectées)
4. ✅ Permissions vérifiées (RBAC appliqué)
5. ✅ Erreurs gérées (cas d'erreur retournent des messages appropriés)
6. ✅ États loading/empty/error/offline traités (indicateurs UI appropriés)
7. ✅ Tests unitaires/intégration pertinents présents (couverture code >80%)
8. ✅ Journalisation nécessaire présente (logs pour débogage et audit)
9. ✅ Aucun secret exposé (credentials jamais dans logs/frontend)
10. ✅ Aucun accès inter-organisation possible (isolation tenant respectée)

## Prochaine étape recommandée

L'utilisateur devrait exécuter les tests unitaires backend pour vérifier que rien n'est cassé:
```bash
cd d:\DEFACT_FACILE\backend
npm run test
```

Puis tester les flux manuellement avec des outils comme Postman ou l'application mobile en mode développement.
# Plan de développement — protegR2

> **Principe de priorisation**
> 1. Ce qui a un impact structurel sur le reste du code passe en premier
> 2. Être fonctionnel le plus rapidement possible
> 3. Les fonctionnalités optionnelles s'ajoutent après
> 4. Les améliorations à réévaluer vont à la fin

---

## Phase 1 — Corrections structurelles (avant tout le reste) ✅

Ces corrections affectent la structure des données et le comportement de base.
Les faire maintenant évite de propager des erreurs dans tout le code suivant.

### 1.1 Sécurité — données de session ✅
- [x] Retirer `hash_password` du fichier de session S3 dans `cookie_set_user()`
- [x] Retirer tous les `print()` qui exposent des données sensibles (`data_to_save_S3`, hash, tokens)
- [x] Vérifier que `cookie_auto_login()` fonctionne toujours sans le hash (il n'en a jamais eu besoin)

### 1.2 Architecture multi-layout — paramètre `style` ✅
- [x] Définir le paramètre `style` dans `protegR2_ui()` : `"sidebar"` | `"navbar"` | `"fluid"` | `"fillable"`
- [x] Concevoir comment `protegR2_load_modules_UIs()` retourne une liste de `nav_panel()` compatible avec tous les styles
- [x] Documenter la convention : l'utilisateur ne passe que des `nav_panel()`, le style décide comment les afficher

---

## Phase 2 — Migration bslib (rendre le package fonctionnel)

### 2.1 Page de login ✅
- [x] Réécrire `protegR2_login_ui.R` avec bslib : `card()` centré sur fond plein écran
- [x] Fond personnalisable (image de fond, couleurs) via CSS dans ce fichier
- [x] Formulaire : username, password, bouton login
- [x] Support touche `Enter` pour soumettre
- [x] Aucun sidebar, aucun navbar — page complètement indépendante du layout choisi

### 2.2 Réécriture de `protegR2_ui()` ✅
- [x] Remplacer `dashboardPage()` / `dashboardHeader()` / `dashboardSidebar()` / `dashboardBody()` par bslib
- [x] Implémenter les 4 styles via `navset_*` dans un `page_fluid()` universel :
  - `"sidebar"` → `navset_pill_list()`
  - `"navbar"` → `navset_underline()`
  - `"fluid"` → `navset_tab()`
  - `"fillable"` → `navset_card_underline()`
- [x] Bouton logout en position fixe (haut droite, z-index 9998)
- [x] Sélecteur de langue optionnel (`idioma = TRUE/FALSE`)
- [x] Injection script Google Analytics si `config_global$ga_id` est présent
- [x] Handler JS `forceDisconnect` pour déconnexion forcée depuis le serveur
- [x] Basculer entre page login et page app via `renderUI()` selon `user_auth()`

### 2.3 Réécriture de `protegR2_server()` + `protegR2_load_modules_UIs()` ✅ ← **DERNIÈRE SESSION**
- [x] Remplacer `add_mod_ui()` / `add_mod_ui_sub()` par des `nav_panel()` et `nav_menu()`
- [x] `protegR2_load_modules_UIs()` retourne une liste de `nav_panel()` — le style décide du rendu
- [x] Sous-menus via `nav_menu()` + `do.call()` pour longueur variable
- [x] Navigation conditionnelle selon le rôle (4 niveaux)
- [x] **Correction bug critique** : `user_auth()` n'était jamais mis à jour après login → ajout explicite dans login manuel et auto-login
- [x] **Protection brute force** : helper `increment_failures()` + `login_failures` reactiveVal. 5 tentatives → verrou 30s
- [x] Ordre de validation login optimisé (verrou → champs → S3 → username → actif → expiration → bcrypt)
- [x] Clés i18n ajoutées : `invalid_credentials`, `empty_fields`, `inactive_account`, `expired_account`, `too_many_attempts`
- [x] Commentaires exhaustifs sur chaque bloc réactif (`observe`, `observeEvent`, `reactive`, `req()`, `throttle`, `invalidateLater`, `do.call`, `reactiveVal`, `session$userData`, `onSessionEnded`)

### 2.4 Gestion des sessions simultanées — popup forceDisconnect
- [ ] La session précédente détecte lors de sa vérification périodique (~45s) que son token n'existe plus
- [ ] Afficher un popup `sweetAlert` : *"Votre session a été ouverte sur un autre appareil. Vous avez été déconnecté."*
- [ ] Le handler JS `forceDisconnect` est déjà en place dans `protegR2_ui()` — brancher côté serveur
- [ ] Note : `cookie_validator_delete()` au login est déjà en place (Phase 2.3)

### 2.5 Restauration de la page au refresh
- [ ] Au changement de page : `updateQueryString("?page=nom_du_panel", mode = "push")`
- [ ] Au login/auto-login : lire l'URL avec `getQueryString()` et naviguer vers la page sauvegardée
- [ ] Fallback sur la page d'accueil si l'URL ne contient pas de page valide

### 2.6 Verrou de compte persistant (brute force S3)
- [ ] Colonne `locked_until` dans `users_auth.rds` (Phase 2.3 fait le verrou local session)
- [ ] Après N tentatives : écrire `locked_until = Sys.time() + Xs` dans le fichier S3
- [ ] Vérification au login avant même de lire le mot de passe
- [ ] Longueur minimale des mots de passe : passer de 5 à 12 caractères dans `protegR2_fct_validate_password()`

---

## Phase 3 — Modules de configuration (rôles & permissions)

### 3.1 Structure rôles/permissions
- [ ] Les 4 rôles restent fixes : `user`, `admin`, `super_admin`, `dev`
- [ ] Les permissions (ce que chaque rôle voit/fait dans l'app) stockées dans `config_global.rds` sur S3
- [ ] Fonction `protegR2_init_config_global()` mise à jour pour inclure les permissions par défaut

### 3.2 Module config utilisateur (`mod_config_ui1` / `user`)
- [ ] Changement de mot de passe (propre compte)
- [ ] Affichage des infos de session (dernière connexion, expiration)

### 3.3 Module config admin (`mod_config_ui2` / `admin`)
- [ ] Créer un `user`
- [ ] Reset de mot de passe pour `user` et `admin`
- [ ] Liste des utilisateurs actifs

### 3.4 Module config super_admin (`mod_config_ui3` / `super_admin`)
- [ ] Créer un `admin`
- [ ] Activer / désactiver un compte
- [ ] Modifier la date d'expiration d'un compte

### 3.5 Module config dev (`mod_config_ui4` / `dev`)
- [ ] Créer un `super_admin`
- [ ] Accès à la configuration globale (`config_global`)
- [ ] Vue des sessions actives

---

## Phase 4 — Fonctionnalités optionnelles

Ces fonctionnalités n'affectent pas le fonctionnement de base.
Elles s'ajoutent une fois que le package est stable et fonctionnel.

### 4.1 Audit log
- [ ] Enregistrer sur S3 : chaque login/logout, IP, timestamp, user-agent, succès/échec
- [ ] Fichier `audit_log.rds` dans `config_files/` sur S3
- [ ] Vue dans le module `dev` et `super_admin`

### 4.2 Blocage de compte après N tentatives
- [ ] Colonne `locked_until` dans `users_auth.rds`
- [ ] Si `Sys.time() < locked_until` : refus immédiat, message explicite
- [ ] Déblocage manuel par `admin` ou déblocage automatique à l'expiration

### 4.3 Token de refresh séparé
- [ ] Deux tokens : `session_token` (courte durée) et `refresh_token` (longue durée)
- [ ] Le `refresh_token` renouvelle silencieusement le `session_token` à expiration
- [ ] Plus robuste : un token volé ne donne pas un accès permanent

### 4.4 Google Analytics
- [ ] Paramètre `ga_id` dans `config_global` (ex. `"G-XXXXXXXXXX"`)
- [ ] `protegR2_ui()` injecte le script GA automatiquement si `ga_id` est présent
- [ ] Rien à faire si `ga_id` est absent

### 4.5 Sélection de langue
- [ ] Déjà partiellement implémenté via `i18n_db`
- [ ] Rendre le sélecteur optionnel via `config_global$idioma = TRUE/FALSE`
- [ ] Placer le sélecteur dans la navbar/header selon le style

### 4.6 Messages et notifications
- [ ] Icône message avec badge dans le header
- [ ] Icône notification avec badge dans le header
- [ ] Panneaux déroulants (style dropdown)
- [ ] Stockage des messages/notifications sur S3

---

## Améliorations à réévaluer plus tard

Ces points sont valides techniquement mais non prioritaires pour l'usage actuel du package.

- **Couche d'abstraction de stockage** (`storage_read()`, `storage_write()`, `storage_exists()`, `storage_delete()`) : permettrait de supporter d'autres backends que S3 (SQLite, PostgreSQL) sans modifier le reste du code. Non prioritaire — `protegR2` est un package personnel qui restera sur S3 pour l'instant.
- **Expiration de session absolue** en plus de la glissante : limite la durée maximale d'une session peu importe l'activité.
- **Notification de connexion** : alerter par email si une connexion depuis un nouvel appareil est détectée.

# Instructions pour Claude

## Identité

Tu es un programmeur R/Shiny/bslib expérimenté, très attentif à la sécurité et à l'expérience utilisateur (UX).

## Approche pédagogique

L'utilisateur veut comprendre tout le code produit — zéro dette technique.

**Pour tout nouveau code :**
- Expliquer le pourquoi des choix, pas juste le quoi
- Commenter le code de façon claire et détaillée directement dans les fichiers
- Signaler quand une approche alternative existe et pourquoi on a choisi celle-là
- Ne pas introduire de complexité sans l'expliquer
- Avant d'écrire du code, expliquer ce qu'on va faire et pourquoi

**Pour la section serveur en particulier :**
- Expliquer chaque bloc `observe`, `observeEvent`, `reactive` — ce qu'il écoute, ce qu'il fait, pourquoi ce choix plutôt qu'un autre
- Expliquer la réactivité Shiny quand elle entre en jeu (pourquoi `req()`, pourquoi `reactiveVal` vs `reactive`, etc.)
- Expliquer les interactions entre session$userData, les reactiveVal, et les outputs
- Commenter chaque section avec un titre clair et une description de son rôle

---

## Plan de développement

Le fichier `inst/package_dev/plan.md` contient le plan de développement détaillé avec toutes les phases, tâches complétées (✅) et à faire (☐). **Consulter ce fichier avant de proposer ou implémenter quoi que ce soit** — les priorités y sont définies et certaines tâches ont déjà été faites.

---

## Git — Règles strictes

- Claude ne peut écrire que sur la branche `claude/dev`
- Ne jamais écrire directement sur `master` ou `dev`
- Le workflow est : Claude travaille sur `claude/dev` → l'utilisateur merge sur `dev` quand satisfait → l'utilisateur merge `dev` sur `master` quand stable
- La branche `claude/dev` est locale uniquement, elle n'est jamais pushée sur GitHub

---

## Description du projet

`protegR2` est un package R d'authentification pour applications Shiny, utilisant bslib (Bootstrap 5) comme système de mise en page. C'est la version modernisée de `protegR` (qui utilisait shinydashboard/Bootstrap 3).

Le stockage des données utilisateurs et des sessions se fait sur AWS S3 via le package maison `s3db`.

---

## Objectifs du package

### Sécurité & Authentification
- Protéger l'accès à l'application Shiny
- Empêcher qu'un même utilisateur soit connecté simultanément sur deux appareils ou navigateurs différents — mécanisme choisi : **détection passive (Option B)** : le 2e login génère un nouveau token qui remplace l'ancien sur S3. La 1ère session détecte lors de sa vérification périodique (toutes les ~45s) que son token n'existe plus, et se déconnecte avec un popup : *"Votre session a été ouverte sur un autre appareil. Vous avez été déconnecté."* Fenêtre de coexistence de ~45s acceptable, pas d'enjeu de sécurité car le token S3 est déjà invalidé
- Déconnexion automatique après une période d'inactivité configurable
- Reconnexion automatique via cookie si la session est encore valide (auto-login au refresh)
- Restauration de la page active au refresh via l'URL (`updateQueryString()` / `?page=monmodule`) — l'utilisateur retrouve la page où il était

### Rôles et permissions

**Les rôles sont fixes (4 niveaux) :**
| Rôle | Description |
|---|---|
| `user` | Accès standard à l'application |
| `admin` | Peut créer des `user`, reset de mot de passe pour `user` et `admin` |
| `super_admin` | Peut créer des `admin` — rôle du chef d'entreprise qui désigne ses admins |
| `dev` | Peut créer des `super_admin` + accès programmation complet |

**Les permissions sont séparées des rôles et configurables :**
- Les permissions (ce que chaque rôle peut voir/faire dans l'application) sont stockées dans `config_global.rds` sur S3
- Elles sont ajustables par projet sans toucher au code
- Cette séparation rôle/permission permet de faire évoluer les accès sans redéployer l'application

### Layouts supportés
Le package doit s'adapter à plusieurs types de pages bslib, sans imposer une structure :
- `"sidebar"` → `page_sidebar()` avec navigation latérale
- `"navbar"` → `page_navbar()` avec navigation en haut
- `"fluid"` → `page_fluid()` + `navset_*` au choix de l'utilisateur
- `"fillable"` → `page_fillable()` pour dashboards plein écran

### Langue
- Sélection de langue optionnelle (français, anglais, espagnol)
- Internationalisation via `i18n_db` intégré au package

### Fonctions d'initialisation
- `protegR2_init()` — copie les fichiers de démarrage dans le projet
- `protegR2_copy_files()` — copie les fichiers modifiables (ui, server, modules)
- `protegR2_init_record_s3_users_auth_file()` — crée le fichier utilisateurs par défaut sur S3
- `protegR2_init_config_global()` — initialise la configuration globale sur S3
- L'objectif est qu'un nouveau projet soit fonctionnel immédiatement après initialisation

### Architecture modules

**Ce qui est dans le package (fonctions exportées, jamais modifiées par l'utilisateur) :**
- Toutes les fonctions d'auth : login, logout, cookies, fingerprint, gestion des sessions
- Les modules de configuration (`mod_config_*`)
- Les fonctions d'initialisation (`protegR2_init`, `protegR2_copy_files`, etc.)

**Ce qui est copié dans le projet utilisateur à l'initialisation :**
- `R/protegR2.R` — contient `protegR2_ui()` et `protegR2_server()`. Copié dans `R/` du projet car pas encore stabilisé comme fonction de package. À terme, quand tout sera testé, ces deux fonctions intégreront directement le package.
- `R/protegR2_login_ui.R` — UI de la page de login, **conçu pour être personnalisé** par projet (fond, logo, couleurs, texte de bienvenue). C'est le seul fichier UI que l'utilisateur est censé modifier.
- `R/protegR2_load_modules_UIs.R` — liste des modules UI à afficher selon le rôle (à personnaliser par projet)
- `R/protegR2_load_modules_servers.R` — liste des modules serveurs à charger (à personnaliser par projet)
- `ui.R` — appelle `protegR2_ui(config_global, style = "sidebar")`
- `server.R` — appelle `protegR2_server(input, output, session)`
- `global.R` — chargement des librairies et de `config_global`

### Page de login — comportement attendu

**Problème avec protegR (shinydashboard) :** la structure fixe header/sidebar/body forçait un sidebar vide sur la page de login. Tenter un `fluidPage` séparé causait des conflits CSS (perte de couleurs dans certaines sections).

**Solution avec bslib :** `protegR2_ui()` affiche deux pages complètement différentes selon l'état de connexion :
- **Non connecté** → `page_fillable()` ou `page_fluid()` simple, sans sidebar ni navbar — juste la `card()` de login centrée sur fond personnalisable
- **Connecté** → le layout choisi (`page_sidebar()`, `page_navbar()`, etc.)

Bslib gère ce changement de structure sans conflits CSS car chaque état est une page indépendante rendue via `renderUI()`. La personnalisation se fait dans `protegR2_login_ui.R` (copié dans `R/` du projet).

### Fonctionnalités futures envisagées
- Système de messages entre utilisateurs (boîte de réception dans le dashboard)
- Système de notifications (alertes, badges animés)

---

## Problèmes de sécurité identifiés (à corriger en priorité)

### 🔴 Critique
1. `hash_password` sauvegardé inutilement dans le fichier de session S3 — à supprimer de `cookie_set_user()`
2. `print(data_to_save_S3)` affiche le hash dans les logs serveur — à supprimer

### 🟠 Sérieux
3. Pas de protection brute force sur le login (pas de délai ni blocage après N tentatives)
4. Longueur minimale du mot de passe = 5 caractères — trop faible, viser 12
5. `cookie_validator_delete()` lit tous les fichiers de session au login — inefficace et expose les données

### 🟡 Modéré
6. Fingerprint basé sur IP + User-Agent uniquement — le User-Agent est falsifiable côté client
7. Pas de flag `HttpOnly` / `Secure` explicite sur le cookie

### ✅ Ce qui est bien
- Hachage bcrypt via `sodium`
- Token de session = UUID v4 aléatoire
- Vérification expiration côté serveur (S3)
- Vérification fingerprint au login automatique
- Nettoyage des tokens expirés au logout
- `just_logged_out` pour éviter le re-login après logout volontaire

---

## Fonctionnalités à implémenter (backlog priorisé)

### À implémenter
1. **Token de refresh séparé du token de session** : deux tokens distincts — un `session_token` (courte durée, dans le cookie) et un `refresh_token` (longue durée, renouvelé silencieusement). Évite qu'un token volé donne un accès permanent.
2. **Restauration de la page active au refresh** : stocker la page active dans l'URL via `updateQueryString()`. Au reload, lire l'URL et naviguer directement au bon endroit. Actuellement l'auto-login fonctionne mais l'utilisateur perd la page où il était.
3. **Audit log** : enregistrer chaque connexion/déconnexion (IP, timestamp, user-agent, succès/échec) dans un fichier sur le backend de stockage — visible par `admin` et `dev`.
4. **Blocage de compte après N tentatives** : colonne `locked_until` dans `users_auth` — si `Sys.time() < locked_until`, refus immédiat sans vérifier le mot de passe.

### À explorer
- **Expiration de session glissante vs absolue** : actuellement glissante (reset à chaque activité) — envisager une expiration absolue maximale en plus
- **Notification de connexion** : alerter l'utilisateur si une connexion depuis un nouvel appareil est détectée

### Google Analytics (optionnel)
- Paramètre `ga_id` dans `config_global` (ex. `"G-XXXXXXXXXX"`)
- `protegR2_ui()` injecte automatiquement le script GA dans `tags$head()` si `ga_id` est présent, ne fait rien sinon
- Zéro configuration pour les projets qui n'en veulent pas
- Permet de tracker : pages visitées, durée de session, origine des utilisateurs, événements personnalisés

### Template `bslibHL` (dépendance externe — package à créer)
- **Nouveau package `bslibHL`** : package maison de composants bslib personnalisés (même logique que `s3db` vis-à-vis de `aws.s3`). Ne remplace pas bslib — coexiste avec lui.
- **`hl_page()`** : layout dashboard avec sidebar de navigation multi-pages. Résout la limitation de `page_sidebar()` de bslib qui ne gère pas nativement la navigation entre pages. API envisagée :
  ```r
  hl_page(
    sidebar = hl_sidebar(
      hl_menu_item("Accueil",    value = "home",    icon = icon("house")),
      hl_menu_item("Finance",    value = "finance", icon = icon("chart-line")),
      hl_menu_item("Paramètres", value = "config",  icon = icon("gear"))
    ),
    hl_panel(value = "home",    ...),
    hl_panel(value = "finance", ...),
    hl_panel(value = "config",  ...)
  )
  ```
- **6e template `protegR2`** : `inst/files_to_copy/template_UIs_style/hl_sidebar.R` — utilise `hl_page()` à la place du bricolage actuel (double navset + observateur de sync). À créer une fois `bslibHL` disponible.

### Améliorations à réévaluer plus tard
- **Couche d'abstraction de stockage** (`storage_read()`, `storage_write()`, etc.) : permettrait de supporter d'autres backends que S3 (SQLite, PostgreSQL) sans modifier le reste du code. Non prioritaire — `protegR2` est un package personnel qui restera sur S3.

---

## Architecture de stockage

### Principe : S3 uniquement via `s3db`
`protegR2` utilise exclusivement **AWS S3 via `s3db`** (package maison, version simplifiée de `aws.s3`). Pas de base de données externe requise.

### Ce qui est stocké
| Fichier | Contenu | Emplacement |
|---|---|---|
| `users_auth.rds` | Utilisateurs, hashes bcrypt, rôles, dates d'expiration | `config_files/` sur S3 |
| `config_global.rds` | Configuration de l'app (cookie_name, langue, ga_id...) | `config_files/` sur S3 |
| `session/{token}.rds` | Token de session, expiration, fingerprint, username | `session/` sur S3 |

---

## Stack technique
- **R** + **Shiny** + **bslib** (Bootstrap 5)
- **sodium** pour le hachage des mots de passe (bcrypt)
- **cookies** pour la gestion des cookies de session
- **s3db** (package maison) pour le stockage sur AWS S3 — backend par défaut
- **uuid** pour la génération des tokens de session
- **shinyjs** pour les interactions JavaScript

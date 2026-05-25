# ══════════════════════════════════════════════════════════════════════════════
# pkg_shiny_test/global.R
# ══════════════════════════════════════════════════════════════════════════════
#
# App de test pour le développement local de protegR2.
# Tourne entièrement sans S3 ni PostgreSQL grâce au mode backend "local".
#
# ── Comment lancer ───────────────────────────────────────────────────────────
#     Ouvrir ce fichier dans RStudio → bouton "Run App"
#     Ou depuis la console (à la RACINE du package) :
#       shiny::runApp("inst/pkg_shiny_test/")
#
# ── Comptes de test disponibles ──────────────────────────────────────────────
#     user1 / pass1      (rôle: user)
#     user2 / pass2      (rôle: user)
#     admin / pass3      (rôle: admin)
#     super_admin / pass4 (rôle: super_admin)
#     dev / pass5        (rôle: dev)
#
# ── Démonstration config_user (layouts multi-pages) ──────────────────────────
#     user1 voit uniquement la page "home"
#     user2 voit uniquement la page "demo"
#     → Même rôle ("user"), pages différentes = séparation rôle / config_user
#
# ══════════════════════════════════════════════════════════════════════════════


# ── Étape 1 : Charger le package depuis les sources ───────────────────────────
# Chaque modification dans R/ est active immédiatement sans réinstaller.
devtools::load_all()

# ── Étape 2 : Charger les bibliothèques nécessaires ───────────────────────────
library(devtools)
library(bslib)
library(bslibHL)


# ── Étape 3 : Choix du style de layout ────────────────────────────────────────
#
# Changer cette valeur pour tester les différents templates de navigation.
#
#   "sidebarHL" → bslibHL::page_sidebarHL() — sidebar multi-pages (recommandé)
#   "navbar"    → page_navbar()             — barre horizontale en haut
#   "sidebar"   → navset_pill_list()        — navigation verticale (mono-page)
#   "fluid"     → navset_tab()              — onglets horizontaux (mono-page)
#   "fixed"     → page_fixed() + navset    — mono-page + engrenage flottant
#   "fillable"  → page_fillable() + navset — dashboard plein écran
#
# Note : la démonstration config_user (user1 vs user2) n'est visible qu'avec
# les layouts multi-pages : sidebarHL et navbar.
style <- "sidebarHL"


# ── Étape 4 : Sourcer les fichiers template ────────────────────────────────────
#
# Ces fichiers ne sont PAS dans R/ — devtools::load_all() ne les charge pas.
# On les source manuellement ici. Dans un vrai projet, ils sont copiés dans R/
# par protegR2_init_layout() et sourcés automatiquement par Shiny.
source("../files_to_copy/R/i18n_db.R")
source("../files_to_copy/R/protegR2_login_ui.R")
source("../files_to_copy/R/protegR2_load_modules_servers.R")
source(paste0("../files_to_copy/template_UIs_style/", style, ".R"))


# ── Étape 5 : Ressources statiques ────────────────────────────────────────────
# /images/background.png → utilisé dans protegR2_login_ui.R
addResourcePath("images", "www")


# ── Étape 6 : Environnement des sessions actives ──────────────────────────────
#
# Trace toutes les sessions Shiny actives pour la déconnexion forcée
# (connexion simultanée sur un autre appareil — mécanisme Option B).
# Défini ici (pas dans le package) car c'est un état global du projet.
sessions <- new.env(parent = emptyenv())


# ── Étape 7 : Configuration ───────────────────────────────────────────────────
#
# Mode local : aucune connexion S3 ni PostgreSQL requise.
# protegR2_local_config() retourne un config_global complet avec les 5
# utilisateurs par défaut et la config_user démo.

#config_global <- protegR2_local_config()            # décommenter pour tester le mode local
#pool <- NULL                                        # pool inutile en mode local


# ── [OPTIONNEL] Basculer vers S3 + PostgreSQL ─────────────────────────────────
# Pour tester avec les vrais backends, commenter les 2 lignes ci-dessus
# et décommenter ce bloc. Prérequis : data/config_s3_location.rds,
# credentials AWS dans .Renviron, tunnel SSH vers Postgres.
#
 s3_connection_HL(config_path = "data/")
 config_global <- s3readRDS_HL(object = "config_files/config_global.rds")
# config_global$protegR2$user_config_backend <- "s3"
 config_global$protegR2$user_config_backend <- "postgres"
 pool <- pool::dbPool(
   drv      = RPostgres::Postgres(),
   dbname   = config_global$protegR2$db$dbname,
   host     = config_global$protegR2$db$host,
   port     = config_global$protegR2$db$port,
   user     = config_global$protegR2$db$user,
   password = config_global$protegR2$db$password,
   minSize  = 2,
   maxSize  = 10
 )
#pool <- NULL


# ── Étape 8 : Validation de la configuration au démarrage ────────────────────
#
# protegR2_startup_check() vérifie que les ressources nécessaires sont
# accessibles selon le backend configuré, et affiche des messages d'aide
# clairs si quelque chose manque.
#
# ── Pour tester les avertissements ──────────────────────────────────────────
# Mode local  : temporairement passer un config_global sans utilisateurs :
#   protegR2_startup_check(modifyList(config_global,
#     list(protegR2 = modifyList(config_global$protegR2,
#       list(local_users_auth = NULL)))))
#
# Mode s3     : renommer temporairement users_auth.rds sur S3 et relancer.
#
# Mode postgres : passer pool = NULL ou pointer vers une table inexistante.

protegR2_startup_check(config_global, pool = pool)

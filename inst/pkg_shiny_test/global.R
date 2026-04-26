# ══════════════════════════════════════════════════════════════════════════════
# dev/app.R — Application de test pour le développement local de protegR2
# ══════════════════════════════════════════════════════════════════════════════
#
# Objectif : tester le package directement depuis les sources, sans pousser
# sur GitHub ni installer. Chaque modification dans R/ est active immédiatement.
#
# ── Comment lancer ──────────────────────────────────────────────────────────
#
#     Ouvrir ce fichier dans RStudio → bouton "Run App" en haut à droite.
#     Ou depuis la console, à la RACINE du package :
#       shiny::runApp("dev/")
#     (Shiny change automatiquement le répertoire de travail vers dev/ au lancement)
#
# ── Prérequis (à faire une seule fois) ─────────────────────────────────────
#
#   1. Avoir le fichier inst/pkg_shiny_test/data/config_s3_location.rds # info du dossier s3 à utiliser
#      Avoir le fichier inst/pkg_shiny_test/data/config_s3_access.rds   # info clé crypté pour S3
#      Les deux fichiers sont GITIGNORE — ne seront jamais poussé sur GitHub.
#      Pour plus d'info, voir le package s3db
#
# ══════════════════════════════════════════════════════════════════════════════


# ── Étape 1 : Charger le package depuis les sources ───────────────────────────
devtools::load_all()

# ── Étape 2 : Charger les bibliothèques nécessaires ───────────────────────────
#
# Deux catégories :
#   A) Packages déclarés dans DESCRIPTION/Imports — chargés automatiquement
#      par devtools::load_all() via le namespace du package. On les recharge
#      ici explicitement pour qu'ils soient disponibles dans l'environnement global
#      (nécessaire pour les fichiers template sourcés à l'étape 3).
#
#   B) Packages NON dans DESCRIPTION — utilisés dans les fichiers template
#      (protegR2.R, modules, etc.) mais pas encore déclarés comme dépendances
#      du package. À ajouter dans DESCRIPTION au fur et à mesure.
#
# Note : si un library() échoue, installer le package manquant avec install.packages().
library(devtools)
#document()
#check()
#use_package("bslib")

#library(shiny)
library(bslib)        # layouts Bootstrap 5 (page_fluid, navset_*, etc.)
#library(dplyr)        # manipulation de données (filter, pull, etc.)
#library(purrr)        # programmation fonctionnelle (map, walk, etc.)
#library(stringr)      # manipulation de chaînes (str_c, etc.)
#library(uuid)         # génération de tokens de session (UUIDgenerate)
#library(rlang)        # opérateur %||% (ou-si-NULL)
#library(magrittr)     # opérateur pipe %>%
#library(cookies)      # gestion des cookies navigateur (add_cookie_handlers, etc.)
#library(s3db)         # accès à AWS S3 (s3readRDS_HL, s3saveRDS_HL, etc.)

# Packages B — utilisés dans les templates, à ajouter dans DESCRIPTION
#library(shinyWidgets) # sendSweetAlert() pour les popups d'erreur au login
#library(shinyjs)      # useShinyjs() dans protegR2_ui()
#library(sodium)       # password_verify() pour la vérification bcrypt
#library(utilsHL)      # make_tr() pour les traductions (remotes::install_github("hugo-lep/utilsHL"))


# ── Étape 3 : Choix du style de layout ────────────────────────────────────────
#
# Changer cette valeur pour tester les différents templates de navigation.
# Dans un projet utilisateur, ce choix est fait une seule fois via
# protegR2_init_layout(style) qui copie le bon fichier dans R/.
#
#   "sidebar"  → navset_pill_list() — navigation verticale à gauche
#   "navbar"   → page_navbar()      — barre horizontale en haut
#   "fixed"    → page_fixed() + navset_tab() + engrenage flottant
#   "fillable" → page_fillable() + navset_card_underline() + engrenage flottant
style <- "sidebar"


# ── Étape 4 : Sourcer les fichiers template ────────────────────────────────────
#
# Ces fichiers vivent dans inst/files_to_copy/ — ils ne font PAS partie du
# package (ils ne sont pas dans R/). devtools::load_all() ne les charge donc pas.
# On les source manuellement ici pour les rendre disponibles.
#
# C'est exactement ce qui se passe dans un projet utilisateur : ces fichiers
# sont copiés dans R/ du projet par protegR2_init_project() et
# protegR2_init_layout(), et R les source automatiquement au démarrage.
#
# Chemins relatifs à pkg_shiny_test/ (répertoire courant quand l'app est lancée).
source("../files_to_copy/R/i18n_db.R")                       # définit i18n_db
source("../files_to_copy/R/protegR2_login_ui.R")             # protegR2_login_ui()
source("../files_to_copy/R/protegR2_load_modules_servers.R") # protegR2_load_modules_servers()

# Le template UI est chargé dynamiquement selon le style choisi ci-dessus.
# Équivalent de ce que protegR2_init_layout(style) copie dans R/ du projet.
source(paste0("../files_to_copy/template_UIs_style/", style, ".R"))


# ── Étape 5 : Ressources statiques ────────────────────────────────────────────
#
# addResourcePath("images", "www") mappe le dossier www/ local au préfixe URL
# /images/ — ce qui permet d'écrire url('/images/background.png') dans le CSS.
# Convention cohérente avec les projets utilisateurs qui utilisent inst/app/www/
# + addResourcePath("images", "inst/app/www") dans leur propre global.R.
addResourcePath("images", "www")

# ── Étape 6 : Configuration de l'application ──────────────────────────────────

# sessions est l'environnement global qui trace toutes les sessions Shiny actives.
# Dans un projet utilisateur, il est défini dans global.R.
# Ici on le recrée pour chaque lancement de l'app de test.
sessions <- new.env(parent = emptyenv())

# Lecture du fichier de localisation S3 (bucket + dossier principal).
# Ce fichier doit exister dans dev/data/ — voir les prérequis en haut de ce fichier.
# Si le fichier n'existe pas, le message d'erreur ci-dessous te guidera.
config_s3_location_path <- "data/config_s3_location.rds"
if (!file.exists(config_s3_location_path)) {
  stop(
    "Fichier manquant : dev/data/config_s3_location.rds\n",
    "Voir les prérequis en haut de dev/app.R pour créer ce fichier."
  )
}
config_s3_location <- readRDS(config_s3_location_path)
#readRDS(paste0("dev/",config_s3_location_path))
# Connexion à S3 — utilise les credentials dans .Renviron
# Si la connexion échoue, vérifier AWS_ACCESS_KEY_ID etc. dans .Renviron
s3_connection_HL(config_path = "data/")

# Chargement de la configuration globale depuis S3
# Ce fichier est créé par protegR2_init_config_global() lors de l'initialisation du projet
config_global <- s3readRDS_HL(object = "config_files/config_global.rds")
key_fmp_api <- config_global$key_fmp_api

# connecter tunnel SSH: ssh -L 5433:127.0.0.1:5432 hugo@158.69.221.155
pool <- pool::dbPool(
  drv      = RPostgres::Postgres(),
  dbname   = "stocktools",
  host     = "localhost",
  port     = 5432,
  user     = config_global$DB_credential$user,
  password = config_global$DB_credential$password,
  minSize = 2,   # connexions maintenues en permanence
  maxSize = 10   # plafond selon tes max_connections Postgres
)

# ── Étape 7 : Overrides locaux de config_global ───────────────────────────────
#
# Surcharge les valeurs lues depuis S3 sans modifier le fichier S3.
#
# show_idioma : TRUE  → sélecteur de langue visible (login + app)
#               FALSE → sélecteur de langue masqué partout
config_global$show_idioma <- TRUE

# supported_idiomas : langues disponibles dans le sélecteur de langue.
# Chaque entrée est une liste avec :
#   mini_label → affiché sur le bouton (ex. "FR")
#   label      → affiché dans le menu déroulant (ex. "Français")
# Pour retirer une langue, supprimer simplement son entrée.
config_global$supported_idiomas <- list(
  fr = list(mini_label = "FR", label = "Français"),
  en = list(mini_label = "EN", label = "English")#,
#  es = list(mini_label = "ES", label = "Español")
)

# ── Étape 8 : Paramètre de layout ──────────────────────────────────────────────
#
# style est défini à l'étape 3 — il détermine le template sourcé et transmis
# à protegR2_ui() via server.R. Changer la valeur à l'étape 3 suffit.


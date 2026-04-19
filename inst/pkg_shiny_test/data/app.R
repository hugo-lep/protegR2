# ══════════════════════════════════════════════════════════════════════════════
# dev/app.R — Application de test pour le développement local de protegR2
# ══════════════════════════════════════════════════════════════════════════════
#
# Objectif : tester le package directement depuis les sources, sans pousser
# sur GitHub ni installer. Chaque modification dans R/ est active immédiatement.
#
# ── Comment lancer ──────────────────────────────────────────────────────────
#
#   Option A (recommandée) :
#     Ouvrir ce fichier dans RStudio → bouton "Run App" en haut à droite.
#     Ou depuis la console, à la RACINE du package :
#       shiny::runApp("dev/")
#     (Shiny change automatiquement le répertoire de travail vers dev/ au lancement)
#
#   Option B :
#     Sélectionner tout le code → Ctrl+Enter.
#     Fonctionne aussi, mais les chemins relatifs partent alors du répertoire courant.
#
# ── Prérequis (à faire une seule fois) ─────────────────────────────────────
#
#   1. Avoir le fichier dev/data/config_s3_location.rds
#      Ce fichier contient le bucket S3 et le dossier principal.
#      Il est GITIGNORE — il ne sera jamais poussé sur GitHub.
#      Pour le créer, ouvrir un projet qui utilise déjà protegR2 et copier
#      le fichier config_s3_location.rds dans dev/data/. Ou le recréer :
#
#        devtools::load_all(".")   # depuis la racine du package
#        set_config_s3_location(
#          s3_bucket      = "mon_bucket",
#          s3_main_folder = "mon_dossier",
#          secure_key     = "ma_cle",
#          config_path    = "dev/data/config_s3_location.rds"
#        )
#
#   2. Avoir les credentials AWS dans .Renviron (à la racine de l'utilisateur) :
#        AWS_ACCESS_KEY_ID     = "..."
#        AWS_SECRET_ACCESS_KEY = "..."
#        AWS_DEFAULT_REGION    = "..."
#        AWS_S3_ENDPOINT       = "..."   # pour OVH ou autre fournisseur
#
#   3. Avoir les packages suivants installés (en plus de ceux du DESCRIPTION) :
#        install.packages(c("shinyWidgets", "shinyjs", "sodium", "devtools"))
#        remotes::install_github("hugo-lep/utilsHL")
#
# ══════════════════════════════════════════════════════════════════════════════


# ── Étape 1 : Charger le package depuis les sources ───────────────────────────
#
# devtools::load_all("..") lit tous les fichiers de R/ du package parent
# et les charge en mémoire — exactement comme library(protegR2) après installation,
# mais sans la compilation et sans l'installation.
#
# ".." = dossier parent de dev/ = racine du package protegR2.
#
# À refaire chaque fois qu'on modifie un fichier dans R/ :
#   Ctrl+Shift+L dans RStudio (shortcut pour load_all)
# OU simplement relancer cette app.
#devtools::load_all("..")
devtools::load_all()
#document()
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

library(shiny)
library(bslib)        # layouts Bootstrap 5 (page_fluid, navset_*, etc.)
library(dplyr)        # manipulation de données (filter, pull, etc.)
library(purrr)        # programmation fonctionnelle (map, walk, etc.)
library(stringr)      # manipulation de chaînes (str_c, etc.)
library(uuid)         # génération de tokens de session (UUIDgenerate)
library(rlang)        # opérateur %||% (ou-si-NULL)
library(magrittr)     # opérateur pipe %>%
library(cookies)      # gestion des cookies navigateur (add_cookie_handlers, etc.)
library(s3db)         # accès à AWS S3 (s3readRDS_HL, s3saveRDS_HL, etc.)

# Packages B — utilisés dans les templates, à ajouter dans DESCRIPTION
library(shinyWidgets) # sendSweetAlert() pour les popups d'erreur au login
library(shinyjs)      # useShinyjs() dans protegR2_ui()
library(sodium)       # password_verify() pour la vérification bcrypt
library(utilsHL)      # make_tr() pour les traductions (remotes::install_github("hugo-lep/utilsHL"))


# ── Étape 3 : Sourcer les fichiers template ────────────────────────────────────
#
# Ces fichiers vivent dans inst/files_to_copy/R/ — ils ne font PAS partie du
# package (ils ne sont pas dans R/). devtools::load_all() ne les charge donc pas.
# On les source manuellement ici pour les rendre disponibles.
#
# C'est exactement ce qui se passe dans un projet utilisateur : ces fichiers
# sont copiés dans R/ du projet par protegR2_copy_files(), et R les source
# automatiquement au démarrage de l'app Shiny.
#
# Chemins relatifs à dev/ (répertoire courant quand l'app est lancée).
source("../inst/files_to_copy/R/i18n_db.R")                      # définit i18n_db
source("../inst/files_to_copy/R/protegR2_login_ui.R")            # protegR2_login_ui()
source("../inst/files_to_copy/R/protegR2_load_modules_UIs.R")    # protegR2_load_modules_UIs()
source("../inst/files_to_copy/R/protegR2_load_modules_servers.R") # protegR2_load_modules_servers()
source("../inst/files_to_copy/R/protegR2.R")                     # protegR2_ui() + protegR2_server()


# ── Étape 4 : Configuration de l'application ──────────────────────────────────

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


# ── Étape 5 : Paramètre de layout ──────────────────────────────────────────────
#
# Changer cette valeur pour tester les différents styles de navigation :
#   "sidebar"  → menu vertical à gauche (navset_pill_list)
#   "navbar"   → onglets horizontaux en haut (navset_underline)
#   "fluid"    → onglets dans une page libre (navset_tab)
#   "fillable" → card plein écran (navset_card_underline)
style <- "sidebar"


# ── Étape 6 : Lancement de l'application ──────────────────────────────────────
#
# shinyApp() crée et lance l'application en mémoire.
# C'est équivalent à avoir un ui.R + server.R dans un dossier Shiny,
# mais condensé en un seul fichier pour le développement.
#
# Le dossier dev/www/ est automatiquement servi par Shiny comme ressources
# statiques accessibles à l'URL / — c'est pourquoi background.png dans
# protegR2_login_ui.R est trouvé sans configuration supplémentaire.
shinyApp(
  ui = protegR2_ui(config_global, style = style),
  server = function(input, output, session) {
    protegR2_server(input, output, session, style = style)
  }
)

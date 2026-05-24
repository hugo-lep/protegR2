# Ce package sert à ajouter un système d'authentification à une "shiny app"
#
# Pré-requis au projet:
#   - Un compte S3/AWS, un bucket et un IAM (idéalement avec accès au dossier principal seulement)
#   - Idéalement un compte GitHub : sauvegarde et passerelle vers le VPS
#   - Optionnel : une instance PostgreSQL sur le VPS (si user_config_backend = "postgres")


# ------ Étape 1 : Copier les fichiers du package dans le projet ---------------

library(protegR2)

# Copie les fichiers de base dans le projet (ui.R, server.R, global.R, R/, www/)
protegR2_init_project(background = TRUE, app = TRUE, R_files = TRUE)

# Copie le template de navigation — choisir parmi :
# "sidebar" | "navbar" | "fluid" | "fillable" | "fixed" | "sidebarHL"
protegR2_init_layout("fluid")


# ------ Étape 2 : Installer les packages --------------------------------------

# Packages CRAN
renv::install(c("here", "shiny", "tidyr", "purrr", "readr",
                "dplyr", "shinyWidgets", "uuid", "stringr",
                "sodium", "cookies", "shinyjs", "glue", "pool", "DBI"))

# Si backend postgres, ajouter aussi :
# renv::install("RPostgres")

# Packages maison (remplacer par le chemin local ou GitHub)
# renv::install(c("hugo-lep/protegR2@dev", "hugo-lep/utilsHL", "hugo-lep/s3db"))


# ------ Étape 3 : Configurer l'accès S3 --------------------------------------

# Enregistre les coordonnées du bucket S3 dans le projet (ajouté à .gitignore)
set_config_s3_location(
  s3_bucket      = "mon_bucket",
  s3_main_folder = "mon_dossier",
  secure_key     = "cle_secrete",
  config_path    = TRUE
)

# Enregistre les credentials AWS S3 (ajouté à .gitignore)
set_config_s3_access(
  s3_ACCESS_KEY_ID     = "abc",
  s3_SECRET_ACCESS_KEY = "abc",
  s3_REGION            = "",
  s3_ENDPOINT          = "s3.bhs.io.cloud.ovh.net",
  config_path          = TRUE
)

# Vérifie la connexion S3
s3_connection_HL()


# ------ Étape 4 : Définir et enregistrer config_global sur S3 ----------------

config_global <- list(

  protegR2 = list(

    # ── Connexion & cookie ──────────────────────────────────────────────────
    dns         = "https://mon-app.example.com",  # URL publique — utilisée pour fetch_client_ip()
    cookie_name = "mon_app",                       # nom du cookie navigateur (unique par projet)

    # ── Langue ──────────────────────────────────────────────────────────────
    lang_choice  = TRUE,
    lang_options = list(
      fr = list(mini_label = "FR", label = "Français"),
      en = list(mini_label = "EN", label = "English"),
      es = list(mini_label = "ES", label = "Español")
    ),
    lang_default = "fr",

    # ── Interface ───────────────────────────────────────────────────────────
    header_title = "Mon App",
    theme = list(
      bootswatch = "darkly",
      primary    = "#3c8dbc"
    ),
    ga_id = NULL,   # Google Analytics ID (ex: "G-XXXXXXXXXX"), NULL = désactivé

    # ── Sécurité ────────────────────────────────────────────────────────────
    security = list(
      token_check_interval_s = 45,      # vérification token toutes les N secondes
      cookie_throttle_ms     = 240000,  # throttle refresh cookie (4 minutes)
      max_login_attempts     = 5,       # tentatives avant verrou temporaire
      lockout_duration_s     = 30,      # durée du verrou en secondes

      # Hosts dont l'accès est restreint aux utilisateurs avec dev_access = TRUE
      # (le rôle "dev" passe toujours). Laisser NULL pour désactiver.
      # Format "hostname + pathname" :
      #   sous-domaine : "voyages-dev.avnumbers.ca/"
      #   sous-dossier : "avnumbers.ca/monapp_dev/"
      restricted_hosts = NULL,

      # En développement local uniquement : simule un host restreint sans déployer.
      # Décommenter dans global.R du projet. Ne jamais mettre une valeur ici.
      override_host = NULL
    ),

    # ── Page de login ───────────────────────────────────────────────────────
    login = list(
      background_img = "/images/background.png",  # chemin relatif Shiny (inst/app/www/)
      welcome_text   = NULL,                       # texte optionnel sous le titre
      logo_url       = NULL,                       # logo optionnel au-dessus du formulaire
      card_width_px  = 420                         # largeur max de la card de login (px)
    ),

    # ── Backend config utilisateur ───────────────────────────────────────────
    # "none"     : pas de config par utilisateur (app simple, tous identiques sauf rôle)
    # "s3"       : config par utilisateur dans config_files/config_user/{username}.rds
    # "postgres" : config par utilisateur dans la table protegr2.user_config (plus rapide)
    user_config_backend = "none",

    # ── Connexion PostgreSQL (requis seulement si user_config_backend = "postgres") ──
    # db = list(
    #   host     = "localhost",  # tunnel SSH en local, IP VPS en prod
    #   port     = 5432,
    #   dbname   = "mon_app",
    #   user     = "mon_app",
    #   password = "..."
    # )

  )

  # ── Autres packages ─────────────────────────────────────────────────────────
  # Ajouter ici les configs spécifiques à chaque package utilisé dans le projet.
  # ,
  # stocktools = list(
  #   api_key = "...",
  #   option  = TRUE
  # )
)

# Enregistrement sur S3
s3saveRDS_HL(config_global, object_name = "config_files/config_global.rds")
message("✅ config_global enregistré sur S3.")


# ------ Étape 5 (postgres seulement) : Créer la DB et l'utilisateur ----------
#
# À faire en superuser dans psql (sudo -u postgres psql) :
#
#   CREATE DATABASE mon_projet;
#   CREATE USER mon_projet WITH PASSWORD 'mot_de_passe';
#   GRANT CONNECT ON DATABASE mon_projet TO mon_projet;
#   GRANT CREATE ON DATABASE mon_projet TO mon_projet;
#   \c mon_projet
#   GRANT USAGE, CREATE ON SCHEMA public TO mon_projet;
#
# Convention : DB et user ont le même nom que le projet.
# Le schéma protegr2 sera créé automatiquement par protegR2_setup() à l'étape suivante.


# ------ Étape 6 : Initialiser les utilisateurs et le backend ------------------

# Crée users_auth.rds sur S3 (toujours).
# Si user_config_backend = "postgres", crée aussi le schéma protegr2 + tables.

# Mode "none" ou "s3" :
protegR2_setup(config_global)

# Mode "postgres" : créer le pool d'abord, puis appeler setup, puis fermer le pool
# pool <- pool::dbPool(
#   drv      = RPostgres::Postgres(),
#   dbname   = config_global$protegR2$db$dbname,
#   host     = config_global$protegR2$db$host,
#   port     = config_global$protegR2$db$port,
#   user     = config_global$protegR2$db$user,
#   password = config_global$protegR2$db$password
# )
# protegR2_setup(config_global, pool = pool)
# pool::poolClose(pool)
#
# ⚠️  Ne pas oublier dans global.R du projet :
#   Créer le pool (pool::dbPool(...)) avec les credentials de config_global$protegR2$db
#
# ⚠️  Ne pas oublier dans server.R du projet :
#   Passer pool = pool à protegR2_server() :
#   protegR2_server(input, output, session, pool = pool)

# Vérifier que les tables ont été créées (mode postgres) :
# DBI::dbGetQuery(pool, "
#   SELECT table_name
#   FROM information_schema.tables
#   WHERE table_schema = 'protegr2'
# ")

# Utilisateurs créés par défaut :
#   user1/pass1       → role = user
#   user2/pass2       → role = user
#   admin/pass3       → role = admin
#   super_admin/pass4 → role = super_admin
#   dev/pass5         → role = dev


# ------ Étape 7 : Déploiement sur le VPS (EC2 / Ubuntu) ----------------------

# Se connecter en SSH et cloner le projet depuis GitHub :
#   git clone git@github.com:hugo-lep/mon_projet.git
#
# Configurer les permissions Linux :
#   sudo chown -R ubuntu:shinyusers mon_projet/
#   sudo chmod -R 2770 mon_projet/
#   sudo usermod -aG shinyusers ubuntu
#   sudo usermod -aG shinyusers shiny
#   newgrp shinyusers
#
# Créer un lien symbolique dans shiny-server :
#   cd /srv/shiny-server
#   sudo ln -s ~/mon_projet
#
# Installer les packages (dans le dossier du projet, ouvrir R) :
#   Sys.setenv(GITHUB_PAT = "ghp_...")  # token GitHub pour les packages maison
#   renv::restore()
#
# Configurer l'accès S3 sur le VPS :
#   set_config_s3_location(...)  # même qu'en local
#   set_config_s3_access(...)    # credentials AWS du VPS
#
# Configurer les permissions du cache renv si partagé entre projets :
#   sudo chown -R ubuntu:shinyusers /home/ubuntu/.cache/R/renv
#   sudo chmod -R 2770 /home/ubuntu/.cache/R/renv
#   sudo chmod g+s /home/ubuntu/.cache/R/renv

# Ce package sert à ajouter un système d'authentification à une "shiny app"
#
# Pré-requis au projet: Avoir un compte S3/aws, un bucket et un IAM (idéalement avec accès au dossier principal seulement)
# Idéalement avoir aussi un compte github: qui sert de sauvegarde et de passerelle via EC2 par la suite
#
#
#
# ------ Première étape: Enregistrer un fichier dans le projet pour documenter les 3 informations suivantes:
# Presque toutes les autres informations relatives à notre projet seront enregistrés sur S3
# 1- nom du bucket
# 2- nom du dossier principal
# 3- sel servant à cripter certaines information
# (Ces 3 informations ne devraient pas être modifiées tout au long de la vie du projet)
# Ces informations sont enregistré dans un fichier dans le projet

# recommandation
library(here)


# copie des fichies nécessaires à l'application par défaut
# La plupart des fichiers sont inclus dans le package protegR2
# Mais certains fichiers devront être modifier en fonction de chaque application à construire.
# Ce sont ces fichiers "à modifier" qui sont copier dans le projet
protegR2_init_project(background = TRUE, app = TRUE, R_files = TRUE)
protegR2_init_layout("fluid")

# Packages CRAN
renv::install(c("here","shiny","tidyr","purrr","readr",
                   "dplyr","shinyWidgets","uuid","stringr","sodium","cookies","shinyjs","glue"))
# Packages perso (utilsHL ici comme exemple, remplacer chemin par ton dossier local ou GitHub)
#renv::install(c("hugo-lep/protegR2@dev","hugo-lep/utilsHL"))



# Enregistrement du fichier + fichier confit_s3_location.rds sera ajouté à .gitignore
# En deux étapes pour ne pas copier cette information sur github
# Un fichier est enregistré en local dans le projet, et ajouté à .gitignore
# Fonction s3db pour configurer car, c'est ensuite ce package qui interragit avec s3

# nouvelle fonction s3db
set_config_s3_location(
  s3_bucket = "my_bucket",
  s3_main_folder = "the_main_folder",
  secure_key = "12345",
  config_path = TRUE
)

# ---- AWS ----------------------------------------------------------------
# ------ 2e étape: enregistrer les informations pour accéder à bucket et dossier principal sur S3

set_config_s3_access(
  s3_ACCESS_KEY_ID = "abc",
  s3_SECRET_ACCESS_KEY = "abc",
  s3_REGION = "",
  s3_ENDPOINT = "s3.bhs.io.cloud.ovh.net",
  config_path = TRUE#,
  #  config_path = config_path
)


# ensuite avec le code suivant, on peut accéder à S3 dans toute notre application
s3_connection_HL()

# ------ 3e étape: Enregistrer nos premiers utilisateurs sur S3
# Après étape 1 (Où sont nos infos sur S3) et étape 2 (comment y accéder)
# Ce fichier contient 5 utilisateurs différents: user1,user2, admin, super_admin, dev
# Si les étapes 1 et 2 on été fait tel qu'expliqué, la fonction ne nécessite pas de variable.

# protegR2_init3_record_s3_users_auth_file() avec lecture automatique de fichier
protegR2_init_record_s3_users_auth_file_default()
#utilisateur par défaut: user/password
# user1/pass1 -> role = user
# user2/pass2 -> role = user
# admin/pass3 -> role = admin
# super_admin/pass4 -> role = super-admin
# dev/pass5 -> role = dev


# Enregistrer sur S3 le fichier qui servira à conserver toutes les informations globales à toutes les sessions
# de cette application, en commençant par le nom du cookie qui sera utiliser.

config_global <- list(

  protegR2 = list(

    # ── Connexion & cookie ──────────────────────────────────────────────────
    dns         = "https://mon-app.example.com",  # URL publique — utilisée pour fetch_client_ip()
    cookie_name = "test",                          # nom du cookie navigateur

    # ── Langue ──────────────────────────────────────────────────────────────
    lang_choice  = TRUE,
    lang_options = list(
      fr = list(mini_label = "FR", label = "Français"),
      en = list(mini_label = "EN", label = "English"),
      es = list(mini_label = "ES", label = "Español")
    ),
    lang_default = "en",

    # ── Interface ───────────────────────────────────────────────────────────
    header_title = "protegR_demo",
    theme = list(
      bootswatch = "darkly",
      primary    = "#3c8dbc"
    ),
    ga_id = NULL,   # Google Analytics ID (ex: "G-XXXXXXXXXX"), NULL = désactivé

    # ── Sécurité ────────────────────────────────────────────────────────────
    security = list(
      token_check_interval_s = 45,      # vérification token S3 toutes les N secondes
      cookie_throttle_ms     = 240000,  # throttle refresh cookie (4 minutes)
      max_login_attempts     = 5,       # tentatives avant verrou temporaire
      lockout_duration_s     = 30,      # durée du verrou en secondes

      # Hosts dont l'accès est restreint aux utilisateurs avec dev_access = TRUE
      # (le rôle "dev" passe toujours, indépendamment de ce flag).
      # Laisser NULL ou vecteur vide pour désactiver la restriction.
      # Ex: c("mon-app-dev.example.com", "staging.example.com")
      restricted_hosts = NULL,

      # Utilisé en développement local UNIQUEMENT pour simuler un host restreint.
      # Décommenter dans global.R du projet pour tester sans déployer.
      # Ne jamais mettre une valeur ici — la surcharge se fait dans global.R.
      override_host = NULL
    ),

    # ── Page de login ───────────────────────────────────────────────────────
    login = list(
      background_img = "/images/background.png",  # chemin relatif Shiny (inst/app/www/)
      welcome_text   = NULL,                       # texte optionnel sous le titre
      logo_url       = NULL,                       # logo optionnel au-dessus du formulaire
      card_width_px  = 420                         # largeur max de la card de login (px)
    )
  )

  # ── Autres packages ─────────────────────────────────────────────────────────
  # Ajouter ici les configs spécifiques à chaque package utilisé dans le projet.
  # Ex:
  # ,
  # mon_package = list(
  #   api_key = "...",
  #   option  = TRUE
  # )
)

# Enregistrement sur S3 — une seule écriture pour tout le config_global
s3saveRDS_HL(config_global, object_name = "config_files/config_global.rds")
message("✅ config_global enregistré sur S3.")

# si Git n'est pas déjà installé sur EC2
# sudo apt update
# sudo apt install git -y   # pour Ubuntu/Debian


# copier le projet sur EC2
# Se connecter sous "ubuntu"
# Copier le projet qui est sur github:
# git clone git@github.com:hugo-lep/finance.git
# git clone git@github.com:hugo-lep/finance.git finance_dev_ # pour copier dans un dossier ayant un nom autre que celui du projet

# Configurer les accès Linux
# (Un utilisateur web sera connecté en tant que utilisateur "shiny"
# 🧾 Donner à 'ubuntu' la propriété du dossier et au groupe 'shinyusers'
# sudo chown -R ubuntu:shinyusers pascan_dev_

# 🔒 Donner les bonnes permissions :
#  - lecture, écriture, exécution pour le propriétaire (ubuntu)
#  - lecture, écriture, exécution pour le groupe (shinyusers)
#  - aucun accès pour les autres
#  - le 2 active le setgid : les nouveaux fichiers hériteront du groupe 'shinyusers'
# sudo chmod -R 2770 pascan_dev_

# ✅ Vérifier le résultat
# ls -ld pascan_dev_

# ➕ Ajouter l’utilisateur ubuntu au groupe shinyusers
# sudo usermod -aG shinyusers ubuntu

# ➕ Ajouter l’utilisateur shiny au groupe shinyusers
# sudo usermod -aG shinyusers shiny

# 🔁 Actualiser la session pour prendre en compte les changements
# newgrp shinyusers

# Créer un raccourci dans /srv/shiny-server/
# cd /srv/shiny-server
# sudo ln -s ~/pascan_dev_

# Installer et accéder aux packages
# dans le dossier du projet, aller dans R
# Renv est détecté automatiquement
# faire: Sys.setenv(GITHUB_PAT = "ghp_....accès git hub nécessaire pour package maison")
# faire: restore() pour installer tous les packages

# Ainsi les packages sont copiés dans un dossier commun à tous les projets, l'utilisateur shiny doit y avoir accès
# sudo chown -R ubuntu:shinyusers /home/ubuntu/.cache/R/renv
# sudo chmod -R 2770 /home/ubuntu/.cache/R/renv
# sudo chmod g+s /home/ubuntu/.cache/R/renv # pour que les nouveaux fichiers/dossiers hérite des mêmes accès

# Même étape qu'en local, copier le fichier indiquant le bucket + dossier principal
# Dans EC2/R
# library(protegR2)
protegR2_init_s3path(s3_bucket = "avnumbers",
                    s3_main_folder = "pascan",
                    secure_key = "12345")

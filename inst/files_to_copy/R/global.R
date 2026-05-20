# Data for all sessions  ---------------------------------------------------------
# * ------ library --------------------------------------------------------
print("global.R")
library(here)
library(readr)
library(shiny)

#database
#library(pool)
#library(RPostgres)

#tidyverse
#library(tidyr)
#library(purrr)

#library(dplyr)
#library(stringr)
#shiny

#library(shinyjs)
#library(shinyWidgets)
#perso
#library(s3db)
#library(utilsHL)
#library(protegR2)
#autre
#library(uuid)
#library(sodium)
#library(cookies)
#library(glue)


addResourcePath("images", "inst/app/www")

sessions <- new.env(parent = emptyenv())

# * ------ AWS connect + load config --------------------------------------
config_s3_location <- read_rds("inst/app/data/config_s3_location.rds")
config_s3_access <- read_rds("inst/app/data/config_s3_access.rds")

s3_connection_HL()
config_global <- s3readRDS_HL(object = "config_files/config_global.rds")
key_fmp_api <- config_global$key_fmp_api
save_path  <- "data/cies_order.rds"

# connecter tunnel SSH: ssh -L 5433:127.0.0.1:5432 hugo@158.69.221.155
con <- dbConnect(
  RPostgres::Postgres(),
  dbname   = "stocktools",
  host     = "localhost",
  port     = 5433,
  user     = config_global$DB_credential$user,
  password = config_global$DB_credential$password
)

# global.R — créé une seule fois au démarrage de l'app
#pool <- pool::dbPool(
#  drv     = RPostgres::Postgres(),
#  dbname  = Sys.getenv("DB_NAME"),
#  host    = Sys.getenv("DB_HOST"),
#  user    = Sys.getenv("DB_USER"),
#  password = Sys.getenv("DB_PASSWORD"),
#  minSize = 2,   # connexions maintenues en permanence
#  maxSize = 10   # plafond selon tes max_connections Postgres
#)

# Fermeture propre quand l'app s'arrête
#onStop(function() pool::poolClose(pool))

config_global <- s3readRDS_HL(object = "config_files/config_global.rds")

# ── Overrides locaux de config_global ─────────────────────────────────────
# Ces lignes surchargent les valeurs lues depuis S3 sans modifier le fichier S3.
# Pratique pour tester localement des options avant de les pousser sur S3.
# Toutes sont optionnelles — commenter celles qui ne sont pas utiles.

# ── Test local : simuler un host restreint ─────────────────────────────────
# Décommenter pour tester le contrôle d'accès dev_access en local (127.0.0.1).
# En production, c'est l'URL réelle du navigateur qui est utilisée.
# NE JAMAIS laisser décommenté sur le serveur.
# config_global$protegR2$security$override_host <- "pascan-dev.avnumbers.ca"

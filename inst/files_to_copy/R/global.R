# Data for all sessions  ---------------------------------------------------------
# * ------ library --------------------------------------------------------
print("global.R")
library(here)

#tidyverse
library(tidyr)
library(purrr)
library(readr)
library(dplyr)
library(stringr)
#shiny
library(shiny)
library(shinyjs)
library(shinyWidgets)
#perso
library(s3db)
library(utilsHL)
library(protegR2)
#autre
library(uuid)
library(sodium)
library(cookies)
library(glue)
#database
library(pool)
library(RPostgres)
#renv::install("RPostgres")

addResourcePath("images", "inst/app/www")

sessions <- new.env(parent = emptyenv())

# * ------ AWS connect + load config --------------------------------------
config_s3_location <- read_rds("inst/app/data/config_s3_location.rds")
config_s3_access <- read_rds("inst/app/data/config_s3_access.rds")

s3_connection_HL()

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

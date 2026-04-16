# Data for all sessions  ---------------------------------------------------------
# * ------ library --------------------------------------------------------
print("global.R")
library(here)
library(shiny)
library(shinydashboard)
library(protegR2)
library(tidyr)
library(purrr)
library(s3db)
library(readr)
library(dplyr)
library(shinyWidgets)
library(uuid)
library(stringr)
library(sodium)
library(cookies)
library(utilsHL)
library(shinyjs)
library(glue)

addResourcePath("images", "inst/app/www")

sessions <- new.env(parent = emptyenv())

# * ------ AWS connect + load config --------------------------------------
config_s3_location <- read_rds("inst/app/data/config_s3_location.rds")
config_s3_access <- read_rds("inst/app/data/config_s3_access.rds")

s3_connection_HL()

config_global <- s3readRDS_HL(object = "config_files/config_global.rds")

#' Copier les fichiers d'aide du package vers le dossier dev/ du projet courant
#'
#' @description
#' Copie tous les fichiers de `inst/files_to_copy/dev` (dans le package) vers le dossier `dev/`
#' du projet courant (là où la fonction est appelée).
#'
#' @return Rien. Les fichiers sont copiés.
#' @export
#'
#' @examples
#' if (interactive()) protegR2_init()
protegR2_init <- function() {
  source_dir <- system.file("files_to_copy", package = "protegR2")
  if (source_dir == "") stop("Le dossier 'inst/files_to_copy/' est introuvable dans le package.")

  ask_overwrite <- function(from, to_dir) {
    to <- file.path(to_dir, basename(from))
    if (file.exists(to)) {
      cat("\U0001f512 Le fichier", to, "existe deja. Ecraser ? [o/N] ")
      answer <- tolower(readLines(n = 1))
      return(answer == "o")
    }
    TRUE
  }

  from <- file.path(source_dir, "dev/01_protegR2_start.R")
  to_dir <- file.path("inst/dev")
  dir.create(to_dir, recursive = TRUE, showWarnings = FALSE)
  if (ask_overwrite(from, to_dir)) {
    file.copy(from, to_dir, overwrite = TRUE)
    message("\u2705 Copie de 01_protegR2_start.R \u2192 inst/dev")

    ligne_a_ajouter <- "inst/dev/01_protegR2_start.R"
    if (file.exists(".gitignore")) {
      lignes <- readLines(".gitignore")
      if (!(ligne_a_ajouter %in% lignes)) {
        write(paste0("\n", ligne_a_ajouter), ".gitignore", append = TRUE)
        message("Fichier '", ligne_a_ajouter, "' ajoute a .gitignore")
      } else {
        message("Fichier '", ligne_a_ajouter, "' est deja present dans .gitignore")
      }
    }
  }
}


#' Copy base project files into the current Shiny project
#'
#' Copies startup files from protegR2 into the current project.
#' Each group of files is controlled by a boolean parameter.
#' Use once at project initialization, then call \code{protegR2_init_layout()}
#' to copy the navigation layout template.
#'
#' @param background Copy \code{background.png} to \code{inst/app/www/}.
#' @param app Copy \code{ui.R}, \code{server.R} and \code{global.R} to the project root.
#' @param R_files Copy \code{R/} files into the project's \code{R/} folder
#'   (\code{i18n_db.R}, \code{protegR2_login_ui.R}, \code{protegR2_load_modules_servers.R}).
#'   \code{protegR2_load_modules_UIs.R} is NOT copied here -- use
#'   \code{protegR2_init_layout()} to copy the right template.
#'
#' @return Nothing. Files are copied into the current project.
#' @export
#'
#' @examples
#' if (interactive()) {
#'   protegR2_init_project(background = TRUE, app = TRUE, R_files = TRUE)
#'   protegR2_init_layout("sidebar")
#' }
protegR2_init_project <- function(background = FALSE, app = FALSE, R_files = FALSE) {
  source_dir <- system.file("files_to_copy", package = "protegR2")
  if (source_dir == "") stop("Le dossier 'inst/files_to_copy/' est introuvable dans le package.")

  ask_overwrite <- function(from, to_dir) {
    to <- file.path(to_dir, basename(from))
    if (file.exists(to)) {
      cat("\U0001f512 Le fichier", to, "existe deja. Ecraser ? [o/N] ")
      answer <- tolower(readLines(n = 1))
      return(answer == "o")
    }
    TRUE
  }

  if (background) {
    from <- file.path(source_dir, "app/www/background.png")
    to_dir <- file.path("inst", "app", "www")
    dir.create(to_dir, recursive = TRUE, showWarnings = FALSE)
    if (ask_overwrite(from, to_dir)) {
      file.copy(from, to_dir, overwrite = TRUE)
      message("\u2705 Copie de background.png \u2192 inst/app/www/")
    }
  }

  if (app) {
    fichiers <- c("ui.R", "server.R", "global.R")
    to_dir <- getwd()

    for (f in fichiers) {
      from <- file.path(source_dir, "R", f)
      if (ask_overwrite(from, to_dir)) {
        file.copy(from, to_dir, overwrite = TRUE)
        message(paste0("\u2705 Copie de ", f, " \u2192 racine du projet"))
      }
    }
  }

  if (R_files) {
    from_dir <- file.path(source_dir, "R")
    r_files  <- list.files(from_dir, pattern = "\\.R$", full.names = TRUE)

    # Exclure les fichiers d'infrastructure (copies par app=TRUE)
    # et protegR2_load_modules_UIs.R (copie par protegR2_init_layout() selon le style).
    exclusions <- c("ui.R", "server.R", "global.R", "protegR2_load_modules_UIs.R")
    r_files    <- r_files[!basename(r_files) %in% exclusions]

    to_dir <- file.path(getwd(), "R")
    dir.create(to_dir, recursive = TRUE, showWarnings = FALSE)

    for (from in r_files) {
      if (ask_overwrite(from, to_dir)) {
        file.copy(from, to_dir, overwrite = TRUE)
        message("\u2705 Copie de ", basename(from), " \u2192 R/")
      }
    }
  }
}


#' Copy a layout template into the project
#'
#' Copies \code{protegR2_load_modules_UIs.R} for the chosen style into
#' \code{R/} of the current project. Run once at project setup.
#'
#' @param style Layout style: \code{"sidebar"}, \code{"fluid"}, \code{"navbar"},
#'   \code{"fixed"}, \code{"fillable"}, or \code{"sidebarHL"}.
#'   \code{"sidebarHL"} requires the \pkg{bslibHL} package and uses
#'   \code{page_sidebarHL()} for multi-page sidebar navigation.
#'
#' @return Nothing. The file is copied into \code{R/} of the current project.
#' @export
#'
#' @examples
#' if (interactive()) {
#'   protegR2_init_layout("sidebar")
#'   protegR2_init_layout("sidebarHL")
#' }
protegR2_init_layout <- function(style = c("sidebar", "fluid", "navbar", "fixed", "fillable", "sidebarHL")) {
  style <- match.arg(style)

  source_dir <- system.file("files_to_copy/template_UIs_style", package = "protegR2")
  if (source_dir == "") {
    stop("Le dossier 'inst/files_to_copy/template_UIs_style/' est introuvable dans le package.")
  }

  from   <- file.path(source_dir, paste0(style, ".R"))
  to_dir <- file.path(getwd(), "R")
  to     <- file.path(to_dir, "protegR2_load_modules_UIs.R")

  dir.create(to_dir, recursive = TRUE, showWarnings = FALSE)

  if (file.exists(to)) {
    cat("\U0001f512 R/protegR2_load_modules_UIs.R existe deja. Ecraser ? [o/N] ")
    answer <- tolower(readLines(n = 1))
    if (answer != "o") {
      message("\u274c Copie annulee.")
      return(invisible(NULL))
    }
  }

  file.copy(from, to, overwrite = TRUE)
  message("\u2705 Template '", style, "' copie \u2192 R/protegR2_load_modules_UIs.R")
  message("   Ouvre ce fichier et remplace les modules de demo par les tiens.")
}


# Initialise le fichier users_auth.rds sur S3 avec 5 utilisateurs par defaut.
# Fonction interne appelee par protegR2_init_record_s3_users_auth_file_default().
# @noRd supprime la generation du .Rd (pas exportee) tout en gardant les @importFrom.
#
#' @importFrom lubridate today
#' @importFrom sodium password_store
#' @importFrom s3db s3_connection_HL s3saveRDS_HL
#' @importFrom sodium data_decrypt
#' @noRd
protegR2_init_record_s3_users_auth_file <- function() {

  s3_connection_HL()

  user_access <- data.frame(
    userID           = 1:5,
    username         = c("user1", "user2", "admin", "super_admin", "dev"),
    hash_password    = c(password_store("pass1"),
                         password_store("pass2"),
                         password_store("pass3"),
                         password_store("pass4"),
                         password_store("pass5")),
    role             = c("user", "user", "admin", "super_admin", "dev"),
    created_by       = rep("protegR2_init", 5),
    inactivity_delay = rep(5, 5),
    active           = TRUE,
    expire_date      = today() + c(7, 8, 9, 10, NA),
    # dev_access : autorise l'acces aux URLs restreintes (restricted_hosts dans config_global).
    # Le role "dev" passe toujours, meme si FALSE — ce flag sert pour les autres roles.
    # Mettre TRUE pour permettre a un utilisateur de tester une version dev/staging.
    dev_access       = c(FALSE, FALSE, FALSE, FALSE, TRUE),
    stringsAsFactors = FALSE
  )

  s3saveRDS_HL(user_access,
               object_name = file.path("config_files", "users_auth.rds"))
}


#' Version par défaut de `protegR2_init_record_s3_users_auth_file`
#'
#' @description
#' Wrapper de la fonction principale. Lit les fichiers `config_s3_access.rds` et `config_s3_location.rds`
#' depuis le dossier `inst/app/data/`, puis appelle `protegR2_init3_record_s_users_auth_file()`.
#'
#' @return Rien.
#' @export
#'
#' @examples
#' if (interactive()) {
#'   protegR2_init_record_s3_users_auth_file_default()
#' }
protegR2_init_record_s3_users_auth_file_default <- function() {
  config_s3_location <- readRDS("inst/app/data/config_s3_location.rds")
  protegR2_init_record_s3_users_auth_file()
}


#' @title créer fichier initial config_global
#'
#' @param name nom du paramètre à ajouter (nom d'une liste)
#' @param value Valeur à insérer dans cette nouvelle liste
#'
#' @importFrom s3db s3exist_HL s3readRDS_HL s3saveRDS_HL
#'
#' @returns Rien, sert à enregistrer un fichier de config_global sur S3
#' @export
#'
#' @examples
#' if(interactive()){
#' protegR2_init_config_global(cookie_name = "test")
#' }
protegR2_init_config_global <- function(name, value) {

  key <- file.path("config_files", "config_global.rds")

  if (!s3exist_HL(object = key)) {
    s3saveRDS_HL(value = list(), object_name = key)
    message("Le fichier global config n'existait pas, il vient d'etre cree.")
  }

  global_config <- s3readRDS_HL(object = key)
  global_config[[name]] <- value
  s3saveRDS_HL(global_config, object_name = key)

  message(paste0("global_config$", name, " = ", value, " a ete ajoute."))
}

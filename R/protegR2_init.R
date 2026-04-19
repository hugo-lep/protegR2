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
      cat("🔒 Le fichier", to, "existe déjà. Écraser ? [o/N] ")
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
    message("✅ Copie de b01_protegR2_start.R→ inst/dev")

    ligne_a_ajouter <- "inst/dev/01_protegR2_start.R"
    if (file.exists(".gitignore")) {
      lignes <- readLines(".gitignore")
      if (!(ligne_a_ajouter %in% lignes)) {
        write(paste0("\n", ligne_a_ajouter), ".gitignore", append = TRUE)
        message("Fichier '", ligne_a_ajouter, "' ajouté à .gitignore")
      } else {
        message("Fichier '", ligne_a_ajouter, "' est déjà présent dans .gitignore")
      }
    }

  }
}






#' Copier les fichiers d'exemple du package vers l'application en construction
#'
#' @description
#' Cette fonction copie certains fichiers inclus dans le package protegR2`
#' vers l'arborescence d'une application Shiny en construction. Chaque groupe est contrôlé par un paramètre booléen.
#' Un message s'affiche si un fichier existe déjà pour demander s’il doit être écrasé.
#'
#' @param background Copier le fichier `background.png` vers `inst/app/www/`.
#' @param app Copier les fichier app.R server.R et global.R
#' @param R_files Copier les fichiers R (sauf `app.R`) vers le dossier `R/`.
#'
#' @return Aucun retour. Les fichiers sont copiés dans le projet courant.
#' @export
#'
#' @examples
#' if (interactive()) {
#'   protegR2_copy_files(background = TRUE, app = TRUE, R_files = TRUE)
#' }
protegR2_copy_files <- function(background = FALSE, app = FALSE, R_files = FALSE) {
  source_dir <- system.file("files_to_copy", package = "protegR2")
  if (source_dir == "") stop("Le dossier 'inst/files_to_copy/' est introuvable dans le package.")

  ask_overwrite <- function(from, to_dir) {
    to <- file.path(to_dir, basename(from))
    if (file.exists(to)) {
      cat("🔒 Le fichier", to, "existe déjà. Écraser ? [o/N] ")
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
      message("✅ Copie de background.png → inst/app/www/")
    }
  }

  if (app) {
    fichiers <- c("ui.R", "server.R", "global.R")
    to_dir <- getwd()

    for (f in fichiers) {
      from <- file.path(source_dir, "R", f)
      if (ask_overwrite(from, to_dir)) {
        file.copy(from, to_dir, overwrite = TRUE)
        message(paste0("✅ Copie de ", f, " → racine du projet"))
      }
    }
  }


  if (R_files) {
    from_dir <- file.path(source_dir, "R")
    r_files <- list.files(from_dir, pattern = "\\.R$", full.names = TRUE)

    # Exclure uniquement les fichiers nommés exactement ui.R, server.R ou global.R
    r_files <- r_files[!basename(r_files) %in% c("ui.R", "server.R", "global.R")]

    to_dir <- file.path(getwd(), "R")
    dir.create(to_dir, recursive = TRUE, showWarnings = FALSE)

    for (from in r_files) {
      if (ask_overwrite(from, to_dir)) {
        file.copy(from, to_dir, overwrite = TRUE)

        message("✅ Copie de", basename(from), "→ R/")
      }
    }
  }
}

#' Initialise un fichier d'authentification utilisateur sur S3
#'
#' @description
#' Cette fonction génère un fichier `users_auth.rds` contenant des utilisateurs par défaut
#' avec des mots de passe hashés, puis l'enregistre sur un bucket S3.
#'
#' @return Rien. La fonction enregistre un fichier `.rds` sur S3.
#' @importFrom lubridate today
#' @importFrom sodium password_store
#' @importFrom s3db s3_connection_HL s3saveRDS_HL
#' @importFrom sodium data_decrypt
#'
#' @examples
#' if (interactive()) {
#'   config_location <- list(
#'     s3_bucket = "mon-bucket",
#'     s3_main_folder = "mon-dossier"
#'   )
#'   protegR2_init_record_s3_users_auth_file()
#' }
protegR2_init_record_s3_users_auth_file <- function() {

  s3_connection_HL()

  user_access <- data.frame(
    userID = 1:5,
    username = c("user1", "user2", "admin", "super_admin", "dev"),
    hash_password = c(password_store("pass1"),
                      password_store("pass2"),
                      password_store("pass3"),
                      password_store("pass4"),
                      password_store("pass5")),
    role = c("user", "user", "admin", "super_admin", "dev"),
    created_by = rep("protegR2_init", 5),
    inactivity_delay = rep(5, 5),
    active = TRUE,
    expire_date = today() + c(7, 8, 9, 10, NA),
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

#  config_s3_location <- readRDS("inst/app/data/config_s3_location.rds")
  key <- file.path("config_files", "config_global.rds")

  if (!s3exist_HL(object = key)) {
    s3saveRDS_HL(value = list(), object_name = key)
    message("Le fichier global config n'existait pas, il vient d'être créé.")
  }

  global_config <- s3readRDS_HL(object = key)
  global_config[[name]] <- value
  s3saveRDS_HL(global_config, object_name = key)

  message(paste0("global_config$", name, " = ", value, " a été ajouté."))
}

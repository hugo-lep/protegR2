# ══════════════════════════════════════════════════════════════════════════════
# user_config_fcts.R
# ══════════════════════════════════════════════════════════════════════════════
#
# Fonctions de lecture et d'écriture de la configuration par utilisateur.
#
# La config utilisateur est structurée par package :
#   list(
#     protegr2   = list(theme = "dark", ...),
#     stocktools = list(watchlist = c("AAPL", "MSFT"), ...)
#   )
#
# Chaque fonction branch selon `user_config_backend` dans config_global :
#   "none"     → NULL (rien à lire/écrire)
#   "s3"       → fichier config_files/config_user/{username}.rds sur S3
#   "postgres" → table protegr2.user_config, colonne config (JSONB)
#
# Ces fonctions sont exportées car elles sont appelées depuis les modules
# du projet (ex. sauvegarder les préférences d'un utilisateur).
# ══════════════════════════════════════════════════════════════════════════════


#' Lire la configuration de l'utilisateur connecté
#'
#' @description
#' Retourne la configuration de l'utilisateur courant sous forme de liste R,
#' structurée par package (`config$protegr2$...`, `config$stocktools$...`, etc.).
#'
#' Retourne une liste vide `list()` si l'utilisateur n'a pas encore de config
#' (première connexion). Retourne `NULL` si `user_config_backend = "none"`.
#'
#' @param session Variable de session Shiny.
#'
#' @return Liste R ou NULL.
#' @export
#'
#' @importFrom s3db s3exist_HL s3readRDS_HL
#' @importFrom DBI dbGetQuery
#' @importFrom jsonlite fromJSON
#' @importFrom rlang %||%
#'
#' @examples
#' \dontrun{
#'   config_user <- get_user_config(session)
#'   lang <- config_user$protegr2$lang %||% "fr"
#' }
get_user_config <- function(session) {

  backend <- session$userData$config_global$protegR2$user_config_backend %||% "none"
  pool    <- session$userData$pool
  user    <- session$userData$user_info$valid_user()

  # Sécurité : ne pas tenter une lecture si l'utilisateur n'est pas encore connecté
  if (is.null(user)) return(NULL)

  if (backend == "none") {

    # ── Mode sans config utilisateur ────────────────────────────────────────
    # App simple : tous les utilisateurs ont la même expérience.
    return(NULL)

  } else if (backend == "local") {

    # ── Mode local (interne au package, pkg_shiny_test uniquement) ───────────
    # "local" est un 4e mode invisible pour l'utilisateur final. Il permet de
    # faire tourner pkg_shiny_test sans S3 ni postgres : users_auth est chargé
    # depuis le code R, les sessions sont en mémoire (.local_sessions).
    # Par conception, ce mode est read-only — tout est perdu au restart du
    # processus R. Stocker une config utilisateur ici n'aurait pas de sens.
    return(NULL)

  } else if (backend == "s3") {

    # ── Lecture sur S3 ───────────────────────────────────────────────────────
    # Fichier RDS par utilisateur — le type R est préservé exactement.
    # Retourne list() si le fichier n'existe pas encore (première connexion).
    path <- paste0("config_files/config_user/", user$username, ".rds")

    if (s3exist_HL(object = path)) {
      return(s3readRDS_HL(object = path))
    }
    return(list())

  } else if (backend == "postgres" && !is.null(pool)) {

    # ── Lecture dans protegr2.user_config ────────────────────────────────────
    # La colonne config est JSONB — DBI la retourne comme chaîne de caractères.
    # jsonlite::fromJSON() la convertit en liste R.
    # simplifyVector = FALSE : force les tableaux JSON à rester des listes R
    # plutôt que d'être aplatis en vecteurs — préserve la structure attendue.
    result <- tryCatch(
      DBI::dbGetQuery(pool,
        "SELECT config FROM protegr2.user_config WHERE user_id = $1",
        list(user$userID)
      ),
      error = function(e) {
        message("Erreur lecture user_config postgres : ", e$message)
        return(NULL)
      }
    )

    if (!is.null(result) && nrow(result) == 1) {
      return(jsonlite::fromJSON(result$config[1], simplifyVector = FALSE))
    }
    return(list())
  }

  return(NULL)
}


#' Écrire la configuration de l'utilisateur connecté
#'
#' @description
#' Sauvegarde la liste `data` comme configuration de l'utilisateur courant.
#' Ne fait rien si `user_config_backend = "none"`.
#'
#' La liste `data` doit être structurée par package :
#' ```r
#' list(
#'   protegr2   = list(theme = "dark"),
#'   stocktools = list(watchlist = c("AAPL", "MSFT"))
#' )
#' ```
#'
#' @param data Liste R à sauvegarder.
#' @param session Variable de session Shiny.
#'
#' @return Invisible NULL.
#' @export
#'
#' @importFrom s3db s3saveRDS_HL
#' @importFrom DBI dbExecute
#' @importFrom jsonlite toJSON
#' @importFrom rlang %||%
#'
#' @examples
#' \dontrun{
#'   config_user <- get_user_config(session)
#'   config_user$stocktools$watchlist <- c("AAPL", "MSFT", "GOOG")
#'   set_user_config(config_user, session)
#' }
set_user_config <- function(data, session) {

  backend <- session$userData$config_global$protegR2$user_config_backend %||% "none"
  pool    <- session$userData$pool
  user    <- session$userData$user_info$valid_user()

  # Sécurité : ne pas écrire si l'utilisateur n'est pas connecté, ou si le
  # backend ne supporte pas la persistance ("none" = pas de config utilisateur,
  # "local" = mode test read-only, sessions en mémoire perdues au restart).
  if (is.null(user) || backend %in% c("none", "local")) return(invisible(NULL))

  if (backend == "s3") {

    # ── Écriture sur S3 ──────────────────────────────────────────────────────
    # Le fichier RDS préserve les types R exactement.
    path <- paste0("config_files/config_user/", user$username, ".rds")
    s3saveRDS_HL(data, object_name = path)
    message("config_user sauvegardée sur S3 pour : ", user$username)

  } else if (backend == "postgres" && !is.null(pool)) {

    # ── Écriture dans protegr2.user_config ───────────────────────────────────
    # auto_unbox = TRUE : les vecteurs de longueur 1 deviennent des scalaires JSON
    # plutôt que des tableaux à un élément — ex. "fr" au lieu de ["fr"].
    # as.character() : force la conversion en chaîne pour le paramètre DBI.
    json_data <- as.character(jsonlite::toJSON(data, auto_unbox = TRUE))

    tryCatch(
      DBI::dbExecute(pool,
        "UPDATE protegr2.user_config
         SET config = $1::jsonb
         WHERE user_id = $2",
        list(json_data, user$userID)
      ),
      error = function(e) {
        message("Erreur écriture user_config postgres : ", e$message)
      }
    )
    message("config_user sauvegardée dans postgres pour : ", user$username)
  }

  invisible(NULL)
}

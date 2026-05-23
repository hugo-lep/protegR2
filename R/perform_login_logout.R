#' Fonction pour se connecter
#'
#' @param valid_user Liste de liste avec les infos de l'utilisateur qui se connecte
#' @param token_value Token de la session à débuter
#' @param input input de la session shiny
#' @param session variable de la session shiny
#'
#' @importFrom stringr str_c
#'
#' @noRd
perform_login <- function(valid_user, token_value, input, session) {

  # Mise à jour des informations de session dans userData
  session$userData$user_info$token_value <- token_value
  session$userData$user_info$valid_user(valid_user)
  session$userData$user_info$user_role(valid_user$role)

  message(str_c("Utilisateur connecté : ", valid_user$username, " | rôle : ", valid_user$role))

  # Enregistrement de la session côté serveur (S3 ou postgres) + cookie navigateur
  cookie_set_user(input = input, session = session)
}

utils::globalVariables(c(
  "Key", "config_s3_location", "expiration", "sessions", "user", "token", "shiny_token"
))

#' Action lors du logout
#'
#' @description
#' Supprime le token de session côté serveur, déconnecte les sessions concurrentes,
#' supprime le cookie navigateur et réinitialise l'état de la session Shiny.
#'
#' @param session Variable de la session shiny
#'
#' @importFrom s3db s3list_HL s3readRDS_HL s3delete_HL
#' @importFrom dplyr pull filter bind_rows
#' @importFrom purrr map map_chr walk
#' @importFrom stringr str_c
#' @importFrom magrittr %>%
#' @importFrom DBI dbExecute
#' @importFrom rlang %||%
#'
#' @noRd
perform_logout <- function(session) {

  token_value      <- session$userData$user_info$token_value
  current_username <- session$user
  backend          <- session$userData$config_global$protegR2$user_config_backend %||% "none"
  pool             <- session$userData$pool

  # ── Suppression du token côté serveur ────────────────────────────────────────
  #
  # Les deux backends suppriment le token courant ET nettoient les tokens expirés
  # en une seule opération pour éviter l'accumulation d'entrées orphelines.

  if (backend == "postgres" && !is.null(pool)) {

    DBI::dbExecute(pool,
      "DELETE FROM protegr2.sessions
       WHERE token_value = $1 OR expiration < NOW()",
      list(token_value)
    )
    message("Token supprimé de protegr2.sessions (postgres)")

  } else {

    token_on_s3 <- s3list_HL(prefix = "session/") %>%
      map_chr("Key", .default = NA_character_) %>%
      as.vector()

    token_on_s3_value <- token_on_s3 %>%
      map(s3readRDS_HL, main_folder = FALSE) %>%
      bind_rows()

    token_expiré  <- token_on_s3_value %>%
      filter(expiration < Sys.time()) %>%
      pull(token_value)

    token_a_effacer  <- c(token_value, token_expiré) %>% unique()
    token_a_effacer2 <- str_c("session/", token_a_effacer, ".rds")
    token_a_effacer2 %>% walk(s3delete_HL)
    message("Token(s) S3 supprimé(s)")
  }

  # ── Déconnexion des sessions Shiny concurrentes du même utilisateur ──────────
  #
  # L'environnement in-memory `sessions` recense toutes les sessions Shiny actives.
  # On envoie forceDisconnect aux autres sessions du même utilisateur
  # (autre onglet, autre appareil). Identique pour S3 et postgres.
  active_shiny_session <- lapply(ls(sessions), function(tok) {
    s <- sessions[[tok]]$session
    list(token = tok, user = s$user)
  }) %>%
    purrr::map_dfr(~tibble(user = .x$user, shiny_token = .x$token))

  shiny_session_to_remove <- active_shiny_session %>%
    filter(user == current_username, shiny_token != session$token) %>%
    pull(shiny_token)

  for (tok in shiny_session_to_remove) {
    s <- sessions[[tok]]$session
    if (!is.null(s)) {
      s$sendCustomMessage("forceDisconnect", list(
        message = "Votre session a été fermée suite à une déconnexion sur un autre appareil ou navigateur."
      ))
    }
    rm(list = tok, envir = sessions)
  }

  # ── Nettoyage cookie + état session ──────────────────────────────────────────
  cookie_remove_user(session)
  session$user <- NULL
  session$userData$user_info$valid_user(NULL)
  session$userData$user_info$user_auth(NULL)
  message("Utilisateur déconnecté.")
}

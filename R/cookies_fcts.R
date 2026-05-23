# ══════════════════════════════════════════════════════════════════════════════
# cookies_fcts.R
# ══════════════════════════════════════════════════════════════════════════════
#
# Fonctions de gestion des sessions : écriture, lecture, suppression.
#
# Chaque fonction branch selon `user_config_backend` dans config_global :
#   "none" / "s3" → fichiers session/{token}.rds sur S3 (comportement original)
#   "postgres"    → table protegr2.sessions dans la DB du projet
#
# Le pool postgres est accessible via session$userData$pool (stocké dans
# protegR2_server() au démarrage, NULL si backend != "postgres").
# ══════════════════════════════════════════════════════════════════════════════


#' Enregistrer la session côté serveur et poser le cookie navigateur
#'
#' @param input input de la session shiny
#' @param session Paramètre de session shiny
#'
#' @importFrom tibble tibble
#' @importFrom s3db s3saveRDS_HL
#' @importFrom cookies set_cookie
#' @importFrom DBI dbExecute
#' @importFrom rlang %||%
#'
#' @noRd
cookie_set_user <- function(input, session) {

  finger_print         <- get_fingerprint(input)
  token_value          <- session$userData$user_info$token_value
  session_timeout_mins <- session$userData$user_info$valid_user()$inactivity_delay
  username             <- session$userData$user_info$valid_user()$username
  cookie_name          <- session$userData$config_global$protegR2$cookie_name
  backend              <- session$userData$config_global$protegR2$user_config_backend %||% "none"
  pool                 <- session$userData$pool
  expiration           <- Sys.time() + (session_timeout_mins * 60)

  if (backend == "postgres" && !is.null(pool)) {

    # ── Enregistrement dans protegr2.sessions ──────────────────────────────
    # ON CONFLICT DO UPDATE : gère les deux cas sans distinction :
    #   - Nouveau login  → INSERT (token inexistant)
    #   - Refresh activité → UPDATE expiration (même token, nouvelle durée)
    DBI::dbExecute(pool,
      "INSERT INTO protegr2.sessions (token_value, username, expiration, finger_print)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (token_value) DO UPDATE
       SET expiration   = EXCLUDED.expiration,
           finger_print = EXCLUDED.finger_print",
      list(token_value, username, expiration, finger_print$fingerprint)
    )
    message("Session enregistrée dans protegr2.sessions (postgres)")

  } else {

    # ── Enregistrement sur S3 ──────────────────────────────────────────────
    # Fichier de session : token, expiration, fingerprint, username.
    # Le hash du mot de passe n'est JAMAIS stocké ici.
    data_to_save_S3 <- tibble(
      token_value  = token_value,
      expiration   = expiration,
      finger_print = finger_print$fingerprint,
      username     = username
    )
    s3saveRDS_HL(
      value       = data_to_save_S3,
      object_name = paste0("session/", token_value, ".rds")
    )
    message("Fichier de session sauvegardé sur S3")
  }

  # ── Cookie navigateur ──────────────────────────────────────────────────────
  # Toujours posé peu importe le backend.
  # Contient uniquement le token (UUID). Expiration alignée sur la session.
  # Ex : 30 min → 30 / 1440 ≈ 0.021 jour.
  set_cookie(
    cookie_name  = cookie_name,
    cookie_value = token_value,
    expiration   = session_timeout_mins / (60 * 24)
  )
  message("Cookie navigateur enregistré")
}


#' Supprimer le cookie navigateur à la déconnexion
#'
#' @param session Paramètre de session shiny
#'
#' @importFrom cookies remove_cookie
#'
#' @noRd
cookie_remove_user <- function(session) {
  remove_cookie(session$userData$config_global$protegR2$cookie_name)
  message("Cookie navigateur supprimé")
}


# Ancienne fonction de refresh de cookie par activité — remplacée par le bloc
# throttled_inputs dans protegR2_server() (Phase 2.3). Conservée ici pour
# référence mais n'est plus appelée. Non exportée.
#
#' @importFrom shiny observeEvent reactiveValuesToList req
#' @importFrom s3db s3exist_HL
#' @noRd
cookie_activity_timestamp <- function(just_logged_out, input, session) {

  observeEvent(reactiveValuesToList(input), {
    req(session$userData$user_info$token_value)
    req(session$userData$user_info$user_auth())
    req(session$userData$config_s3_location$s3_main_folder)

    now <- Sys.time()
    session$userData$timestamp_activity(now)
    session_token <- session$userData$user_info$token_value
    file_path <- paste0("session/", session_token, ".rds")

    if (!s3exist_HL(object = file_path)) {
      just_logged_out(TRUE)
      session$userData$user_info$user_auth(NULL)
    }

    if (as.numeric(difftime(now, session$userData$timestamp_cookie(), units = "secs")) >
        session$userData$config_global$protegR2$security$cookie_throttle_ms / 1000) {
      cookie_set_user(input, session)
      session$userData$timestamp_cookie(now)
    }
  })
}


utils::globalVariables(c("finger_print"))

#' Reconnexion automatique via cookie si la session est encore valide
#'
#' @description
#' Lit le cookie du navigateur, vérifie la session côté serveur (S3 ou postgres)
#' et retourne les données de session si valides, NULL sinon.
#'
#' @param input variable input de la session shiny
#' @param session variable session de la session shiny
#'
#' @importFrom cookies get_cookie
#' @importFrom s3db s3exist_HL s3readRDS_HL
#' @importFrom DBI dbGetQuery
#' @importFrom rlang %||%
#'
#' @noRd
cookie_auto_login <- function(input, session) {

  cookie_token <- cookies::get_cookie(session$userData$config_global$protegR2$cookie_name)

  # Pas de cookie → rien à faire
  if (is.null(cookie_token)) return(NULL)

  finger_print_var <- get_fingerprint(input)
  backend          <- session$userData$config_global$protegR2$user_config_backend %||% "none"
  pool             <- session$userData$pool

  if (backend == "postgres" && !is.null(pool)) {

    # ── Vérification dans protegr2.sessions ───────────────────────────────
    # La requête vérifie en une seule fois : token, fingerprint, et expiration.
    # Si une seule ligne retournée → session valide.
    result <- tryCatch(
      DBI::dbGetQuery(pool,
        "SELECT token_value, username, expiration, finger_print
         FROM protegr2.sessions
         WHERE token_value  = $1
           AND finger_print = $2
           AND expiration   > NOW()",
        list(cookie_token, finger_print_var$fingerprint)
      ),
      error = function(e) {
        message("Erreur lecture session postgres : ", e$message)
        return(NULL)
      }
    )
    if (!is.null(result) && nrow(result) == 1) return(result)

  } else {

    # ── Vérification sur S3 ────────────────────────────────────────────────
    file_path <- paste0("session/", cookie_token, ".rds")
    if (s3exist_HL(object = file_path)) {

      S3_save_cookie <- tryCatch(
        s3readRDS_HL(file_path),
        error = function(e) {
          message("Erreur lors de la lecture du cookie : ", e$message)
          return(NULL)
        }
      )

      if (!is.null(S3_save_cookie)) {
        S3_save_cookie_valid <- S3_save_cookie %>%
          filter(finger_print == finger_print_var$fingerprint,
                 expiration > Sys.time())

        if (nrow(S3_save_cookie_valid) == 1) return(S3_save_cookie_valid)
      }
    }
  }

  return(NULL)
}


utils::globalVariables(c("fichier"))

#' Supprimer les tokens de session d'un ou plusieurs utilisateurs
#'
#' @description
#' Appelé au login pour invalider les sessions précédentes du même utilisateur
#' (mécanisme de détection de session simultanée — Option B).
#'
#' @param users Vecteur de noms d'utilisateurs dont on veut supprimer les sessions
#' @param session variable de la session shiny
#'
#' @importFrom purrr map_dfr walk
#' @importFrom dplyr pull bind_rows filter mutate
#' @importFrom s3db s3list_HL s3delete_HL s3readRDS_HL
#' @importFrom DBI dbExecute
#' @importFrom rlang %||%
#'
#' @noRd
cookie_validator_delete <- function(users, session) {

  backend <- session$userData$config_global$protegR2$user_config_backend %||% "none"
  pool    <- session$userData$pool

  if (backend == "postgres" && !is.null(pool)) {

    # ── Suppression dans protegr2.sessions ────────────────────────────────
    # Un DELETE par utilisateur — simple et lisible.
    for (u in users) {
      DBI::dbExecute(pool,
        "DELETE FROM protegr2.sessions WHERE username = $1",
        list(u)
      )
    }
    message("Session(s) supprimées dans postgres pour : ", paste(users, collapse = ", "))

  } else {

    # ── Suppression sur S3 ────────────────────────────────────────────────
    objets   <- s3list_HL(prefix = "session/")
    fichiers <- sapply(objets, function(x) x[["Key"]])

    if (length(fichiers) > 0) {
      files_to_delete <- fichiers %>%
        map_dfr(~ s3readRDS_HL(.x, main_folder = FALSE) %>%
                  mutate(fichier = .x)) %>%
        bind_rows() %>%
        filter(username %in% users) %>%
        pull(fichier)

      files_to_delete %>% walk(s3delete_HL, main_folder = FALSE)
      message("Cookie validator(s) S3 supprimé(s)")
    }
  }
}

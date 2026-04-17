#' Fonction pour enregistrer un cookie
#'
#' @param input input de la session shiny
#' @param session Paramètre de session shiny
#'
#' @importFrom tibble tibble
#' @importFrom stringr str_c
#' @importFrom s3db s3saveRDS_HL
#' @importFrom cookies set_cookie
#'
#' @returns Ne retourne rien, mais enregistre un cookie et met à jour le "cookie validator" (fichier sur S3)
#' @export
#'
#' @examples
#' if(interactive()){
#' cookie_set_user(input,session)
#' }
cookie_set_user <- function(input, session) {
  message("############################## user_cookie_set: début #####################################")

  finger_print        <- get_fingerprint(input)
  token_value         <- session$userData$user_info$token_value
  session_timeout_mins <- session$userData$user_info$valid_user()$inactivity_delay
  username            <- session$userData$user_info$valid_user()$username
  cookie_name         <- session$userData$config_global$cookie_name

  # Fichier de session sauvegardé sur S3 — contient uniquement ce qui est
  # nécessaire pour valider la session : token, expiration, fingerprint, username.
  # Le hash du mot de passe n'est JAMAIS stocké ici (inutile + risque de sécurité).
  data_to_save_S3 <- tibble(
    token_value  = token_value,
    expiration   = Sys.time() + (session_timeout_mins * 60),
    finger_print = finger_print$fingerprint,
    username     = username
  )

  s3saveRDS_HL(
    value       = data_to_save_S3,
    object_name = paste0("session/", token_value, ".rds")
  )
  message("Fichier de session sauvegardé sur S3 : token / expiration / fingerprint / username")

  # Le cookie côté navigateur contient uniquement le token (UUID aléatoire).
  # TODO : déterminer le format exact attendu par la version installée de {cookies}
  # pour le paramètre expiration. En attendant, 1 jour fixe — suffisant pour tester.
  set_cookie(cookie_name  = cookie_name,
             cookie_value = token_value,
             expiration   = 1)

  message("Cookie navigateur enregistré")
  message("############################## user_cookie_set: fin #####################################")
}


#' Fonction pour enregistrer un cookie
#'
#' @description
#' Principalement utiliser avec le bouton logout et inactivity
#'
#' @param session Paramètre de session shiny
#'
#' @importFrom cookies remove_cookie
#'
#' @returns Ne retourne rien, mais efface le cookie
#' @export
#'
#' @examples
#' if(interactive()){
#' cookie_remove_user(session)
#' }
cookie_remove_user <- function(session) {

  remove_cookie(session$userData$config_global$cookie_name)
  message("cookies deleted")
}


#' update cookie et cookie validator lors d'un input
#'
#' @param just_logged_out reactiveVal servant à éviter le cookie auto-connect
#' @param input Variable input de la session shiny
#' @param session Variable de la session shiny
#'
#' @importFrom shiny observeEvent reactiveValuesToList req
#' @importFrom lubridate now
#' @importFrom s3db s3exist_HL
#'
#' @returns Ne retourne rien, mais met à jour le cookie et cookie validator
#' @export
#'
#' @examples
#' if(interactive()){
#' cookie_actvity_timestamp(input, session)
#' }
cookie_actvity_timestamp <- function(just_logged_out, input, session) {

  observeEvent(reactiveValuesToList(input), {
    req(session$userData$user_info$token_value)
    req(session$userData$user_info$user_auth())
    req(session$userData$config_s3_location$s3_main_folder)

    now <- Sys.time()
    session$userData$timestamp_activity(now)
    session_token <- session$userData$user_info$token_value
    file_path <- paste0("session/", session_token, ".rds")

    if (!s3exist_HL(object = file_path)) {
      print("from cookie_activity_timestamp: cookie validator n'existe pas")
      just_logged_out(TRUE)
      session$userData$user_info$user_auth(NULL)

    } else {
      print("from cookie_activity_timestamp: *** il y a un cookie validator ***")
    }

    if (as.numeric(difftime(now, session$userData$timestamp_cookie(), units = "secs")) > session$userData$config_global$cookie_update_time) {

      cookie_set_user(input, session)
      session$userData$timestamp_cookie(now)
    }
  })
}

utils::globalVariables(c(
  "finger_print"
))
#' Reconnection automatique si fingerprint == cookie validator non expiré
#'
#' @param input variable input de la session shiny
#' @param session variable session de la session shiny
#'
#' @importFrom cookies get_cookie
#' @importFrom s3db s3exist_HL s3readRDS_HL
#'
#' @returns Rien, mais modifie user_auth(), ce qui fait basculer dans l'application principale plutôt que la page d'authentification
#' @export
#'
#' @examples
#' if(interactive()){
#' cookie_auto_login(input,session)
#' }
cookie_auto_login <- function(input, session) {

  cookie_token <- cookies::get_cookie(session$userData$config_global$cookie_name)
  print(paste("from cookie_auto_login: cookie_token:", cookie_token))

  # s'il n'y a pas de token (avec le nom spécifié par config_global), tout le code dans le if() n'est pas exécuté
  if (!is.null(cookie_token)) {

    file_path <- paste0("session/", cookie_token, ".rds")
    if (s3exist_HL(object = file_path)) {

      finger_print_var <- get_fingerprint(input)
      print(finger_print_var)

      # Récupération sécurisée du fichier
      S3_save_cookie <- tryCatch(
        s3readRDS_HL(file_path),
        error = function(e) {
          message("Erreur lors de la lecture du cookie : ", e$message)
          return(NULL)
        }
      )
      #      test <- s3readRDS(object = "MBHL/session/ab9e45a0-7e4a-4c73-8475-5f3a51ab74b6.rds",
      #                        bucket = "avnumbers")

      # Vérifie si l'utilisateur existe dans la base des utilisateurs
      if (!is.null(S3_save_cookie)) {
        # Vérification de la validité du cookie
        S3_save_cookie_valid <- S3_save_cookie %>%
          filter(finger_print == finger_print_var$fingerprint,
                 expiration > Sys.time())

        if (nrow(S3_save_cookie_valid) == 1) {
          return(S3_save_cookie_valid)
        }
      }
    }
  }
  return(NULL)
}


utils::globalVariables(c(
  "fichier"
))
#' Delete cookie validator
#'
#' @param users (chr) vector avec les noms des users pour qui on veut effacer les cookie validators
#' @param session variable de la session shiny
#'
#' @importFrom stringr str_c
#' @importFrom purrr map_dfr
#' @importFrom dplyr pull bind_rows filter
#' @importFrom s3db s3list_HL s3delete_HL
#'
#' @returns Rien mais efface les cookies validators sur S3
#' @export
#'
#' @examples
#' if(interactive()){
#' cookie_validator_delete(users,session)
#' }
cookie_validator_delete <- function(users, session) {

  objets <- s3list_HL(prefix = "session/")
  fichiers <- sapply(objets, function(x) x[["Key"]])

  if(length(fichiers) > 0) {
    files_to_delete <- fichiers %>%
      map_dfr(~ s3readRDS_HL(.x, main_folder = FALSE) %>%
                mutate(fichier = .x)) %>%
      bind_rows() %>%
      filter(username %in% users) %>%
      pull(fichier)

    files_to_delete %>% walk(s3delete_HL, main_folder = FALSE)

    print("cookie validator(s) effacé(s)")

  } else {
    NULL
  }
}

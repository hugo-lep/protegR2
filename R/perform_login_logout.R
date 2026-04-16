#' Fonction pour se connecter
#'
#' @param valid_user Liste de liste avec les infos de l'utilisateur qui se connecte
#' @param token_value Token de la session à débuter
#' @param input input de la session shiny
#' @param session variable de la session shiny
#'
#' @importFrom stringr str_c
#'
#' @returns Ne retourne rien, mais enregistre un token et modifie l'utilisateur actif
#' @export
#'
#' @examples
#' if(interactive()){
#' perform_login(valid_user,token_value,session)
#' }
perform_login <- function(valid_user, token_value, input, session) {
  print("############################## perform login: début #####################################")

  session$userData$user_info$token_value <- token_value
  session$userData$user_info$valid_user(valid_user)
  session$userData$user_info$user_role(valid_user$role)

  print(str_c("user_auth = ", valid_user$username))

  print(str_c("token value au login: ", session$userData$user_info$token_value))
  cookie_set_user(input = input, session = session)

  print(session$userData$user_info)

  print("############################## perform login: terminé #####################################")
}

utils::globalVariables(c(
  "Key", "config_s3_location", "expiration", "sessions", "user", "token", "shiny_token"
))
#' Action lors du logout
#'
#' @description
#' Efface le token et le cookie de la session et ensuite déconnecte l'utilisateur
#'
#'
#' @param session Variable de la session shiny
#'
#' @importFrom s3db s3list_HL s3readRDS_HL s3delete_HL
#' @importFrom dplyr pull filter bind_rows
#' @importFrom purrr map map_chr walk
#' @importFrom stringr str_c
#' @importFrom magrittr %>%
#'
#' @returns Rien, mais modifie des paramètre
#' @export
#'
#' @examples
#' if(interactive()){
#' perform_logout(session)
#' }
perform_logout <- function(session) {

  token_value <- session$userData$user_info$token_value
  token_on_s3 <- s3list_HL(prefix = "session/") %>%
    map_chr("Key", .default = NA_character_) %>%
    as.vector()

  token_on_s3_value <- token_on_s3 %>%
    map(s3readRDS_HL, main_folder = FALSE) %>%
    bind_rows()

  print("token_on_s3_value")
  print(token_on_s3_value)

  # *----- Nettoyage token avnumbers -----------------------------------------------
  token_expiré <- token_on_s3_value %>%
    filter(expiration < Sys.time()) %>%
    pull(token_value)

  token_a_effacer <- if (length(token_expiré) == 0) {
    token_value
  } else {
    c(token_value, token_expiré) %>% unique()
  }

  token_a_effacer2 <- str_c("session/", token_a_effacer, ".rds")

  token_a_effacer2 %>%
    walk(s3delete_HL)
  message("token(s) serveur nettoyé(s")

  # *----- Nettoyage var global sessions -----------------------------------------------
  active_user_cookie_validator <- token_on_s3_value %>%
    filter(expiration > Sys.time()) %>%
    pull(username)

  print("active_user_cookie_validator")
  print(active_user_cookie_validator)
  ls(sessions)

  active_shiny_session <- lapply(ls(sessions), function(tok) {
    s <- sessions[[tok]]$session   # accès à la session Shiny
    list(
      token = tok,
      user  = s$user
    )
  }) %>%
    purrr::map_dfr(~tibble(
      user        = .x$user,
      shiny_token = .x$token
    ))


  print("active_shiny_session")
  print(active_shiny_session)
  print(ls(sessions))

  shiny_session_to_remove <- active_shiny_session %>%
    filter(!user %in% active_user_cookie_validator) %>%
    pull(shiny_token)

  for (tok in shiny_session_to_remove) {
    s <- sessions[[tok]]$session
    if (!is.null(s)) {
      s$sendCustomMessage("forceReload", list())
    }
    rm(list = tok, envir = sessions)
  }


  # *----- Nettoyage cookie + disconnect -----------------------------------------------


  cookie_remove_user(session)

  session$user <- NULL
  session$userData$user_info$valid_user(NULL)
  session$userData$user_info$user_auth(NULL)  # met à jour le reactiveVal

  message("Utilisateur déconnecté.")
}

#' Fonction pour vérifier si deux passwords sont identiques (et minimum 5 caractère)
#'
#' @param pwd1 (chr) Password 1
#' @param pwd2 (chr) Password 1
#' @param min_length (num) Nombre de caractère minimum pour le password
#'
#' @importFrom shiny showNotification
#' @importFrom stringr str_glue
#'
#' @noRd
protegR2_fct_validate_password <- function(pwd1, pwd2, min_length = 5) {

  if (pwd1 != pwd2) {
    showNotification("Les deux mots de passe ne correspondent pas.", type = "error")
    return(FALSE)
  }
  if (nchar(pwd1) < min_length) {
    showNotification(str_glue("Le mot de passe doit contenir au moins {min_length} caractères."), type = "warning")
    return(FALSE)
  }
  return(TRUE)
}
utils::globalVariables(c(
  "hash_password"
))
#' Fonction pour modifier un password
#'
#' @param username Username pour lequel on veut changer le password
#' @param new_hash Password hashé
#' @param config_s3_location Information pour l'enregistrement sur S3
#'
#' @importFrom dplyr mutate if_else
#' @importFrom s3db s3readRDS_HL s3saveRDS_HL
#'
#' @noRd
protegR2_fct_change_pwd <- function(username,
                                   new_hash,
                                   config_s3_location) {
  # Sauvegarde du nouveau hachage
  print("read users_auth.rds")
  user_auth_updated <- s3readRDS_HL("config_files/users_auth.rds") %>%
    mutate(hash_password = if_else(username == as.character({{username}}),
                                   new_hash, hash_password))

  s3saveRDS_HL(user_auth_updated,
            object_name = "config_files/users_auth.rds")

  # Notification de succès
  showNotification("Mot de passe modifié avec succès.", type = "message")
}

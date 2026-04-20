# ── Helper interne — appel de fonctions définies dans le projet utilisateur ───
#
# Problème :
#   protegR2_server() est une fonction de package. Quand le package est installé
#   (via renv::install, devtools::install, etc.), ses fonctions vivent dans le
#   namespace du package. La chaîne de recherche de symboles est :
#     namespace protegR2 → imports → base → environnement vide
#   Le globalenv() du projet utilisateur N'EST PAS dans cette chaîne.
#
#   Avec devtools::load_all(), ça fonctionne "par accident" car load_all() place
#   le namespace dans un environnement dont le parent est globalenv() — ce qui
#   n'est pas le cas d'un package proprement installé.
#
# Solution :
#   project_fn() récupère explicitement une fonction depuis globalenv(), là où
#   Shiny source les fichiers R/ du projet utilisateur au démarrage de l'app.
#   Fonctionne dans les deux cas : package installé ET devtools::load_all().
#
# Utilisation :
#   project_fn("ma_fonction")(arg1, arg2)
#
# Les trois fonctions concernées dans protegR2 :
#   - protegR2_login_ui()             → apparence de la page de login
#   - protegR2_load_modules_UIs()     → liste des nav_panel() selon le rôle
#   - protegR2_load_modules_servers() → démarrage des modules Shiny du projet

#' Recupere une fonction definie dans le projet utilisateur
#'
#' Helper interne utilise par \code{protegR2_server()} pour appeler les trois
#' fonctions que l'utilisateur definit dans \code{R/} de son projet :
#' \code{protegR2_login_ui()}, \code{protegR2_load_modules_UIs()} et
#' \code{protegR2_load_modules_servers()}.
#'
#' Ces fonctions vivent dans \code{globalenv()} (sourcees par Shiny au
#' demarrage). Un package installe ne peut pas les trouver par appel direct
#' car son namespace ne pointe pas vers \code{globalenv()}. \code{project_fn()}
#' contourne ce probleme avec \code{get(..., envir = globalenv())}.
#'
#' @param name Nom de la fonction a recuperer depuis \code{globalenv()}
#'
#' @return La fonction recuperee, prete a etre appelee
#'
#' @noRd
project_fn <- function(name) {
  tryCatch(
    get(name, envir = globalenv(), inherits = TRUE),
    error = function(e) stop(
      "Fonction '", name, "' introuvable dans le projet. ",
      "Verifie que le fichier R/", name, ".R existe dans ton projet ",
      "et qu'il definit bien cette fonction.",
      call. = FALSE
    )
  )
}

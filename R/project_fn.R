# ── Helper interne — appel de fonctions définies dans le projet utilisateur ───
#
# Problème :
#   protegR2_server() est une fonction de package installé. Son namespace ne
#   pointe pas vers l'environnement de l'application Shiny.
#
#   Depuis Shiny 1.5, les fichiers R/ du projet sont sourcés dans un
#   environnement ENFANT de globalenv() — la closure de la fonction server().
#   Un appel direct (protegR2_load_modules_servers()) depuis un package échoue
#   car le namespace cherche dans : namespace → imports → base → vide.
#   get(..., envir = globalenv()) échoue aussi : il cherche dans globalenv() et
#   ses PARENTS, jamais dans ses enfants.
#
# Solution :
#   sys.frames() retourne tous les environnements d'exécution de la pile
#   d'appels courante. En cherchant dans chacun avec inherits = TRUE, on
#   remonte aussi dans leurs closures — ce qui permet d'atteindre
#   l'environnement Shiny où R/ a été sourcé.
#
#   Fonctionne dans les deux cas :
#     - Package installé (renv::install / devtools::install)
#     - devtools::load_all() (où le namespace pointe déjà vers globalenv)

#' Recupere une fonction definie dans le projet utilisateur
#'
#' Helper interne utilise par \code{protegR2_server()} pour appeler les trois
#' fonctions que l'utilisateur definit dans \code{R/} de son projet :
#' \code{protegR2_login_ui()}, \code{protegR2_load_modules_UIs()} et
#' \code{protegR2_load_modules_servers()}.
#'
#' Depuis Shiny 1.5, les fichiers \code{R/} sont sources dans un environnement
#' enfant de \code{globalenv()}, inaccessible directement depuis un namespace
#' de package. \code{project_fn()} remonte la pile d'appels via
#' \code{sys.frames()} pour atteindre cet environnement.
#'
#' @param name Nom de la fonction a recuperer
#'
#' @return La fonction recuperee, prete a etre appelee
#'
#' @noRd
project_fn <- function(name) {
  # Parcourir tous les environnements d'exécution de la pile d'appels.
  # Pour chaque frame, inherits = TRUE remonte aussi dans sa closure,
  # ce qui permet d'atteindre l'environnement Shiny où R/ a été sourcé.
  for (env in sys.frames()) {
    if (exists(name, envir = env, inherits = TRUE)) {
      return(get(name, envir = env, inherits = TRUE))
    }
  }

  stop(
    "Fonction '", name, "' introuvable dans le projet. ",
    "Verifie que le fichier R/", name, ".R existe dans ton projet ",
    "et qu'il definit bien cette fonction.",
    call. = FALSE
  )
}

#' Recupere une variable definie dans le projet utilisateur
#'
#' Complement de \code{project_fn()} pour les \strong{variables} (listes,
#' data frames, etc.) definies dans \code{R/} du projet utilisateur.
#'
#' Meme probleme de portee que pour les fonctions : depuis un package installe,
#' le namespace ne peut pas atteindre les variables sourcees dans l'environnement
#' Shiny. Ce helper remonte \code{sys.frames()} pour les trouver.
#'
#' Doit etre appele dans un contexte non-reactif (demarrage du server), jamais
#' depuis un \code{reactive()}, \code{observe()} ou \code{renderUI()} —
#' la pile d'appels y est differente.
#'
#' @param name Nom de la variable a recuperer
#'
#' @return La valeur de la variable
#'
#' @noRd
project_var <- function(name) {
  # Meme mecanique que project_fn() : remonter sys.frames() avec inherits = TRUE
  # pour atteindre l'environnement enfant de globalenv() où Shiny a sourcé R/.
  for (env in sys.frames()) {
    if (exists(name, envir = env, inherits = TRUE)) {
      return(get(name, envir = env, inherits = TRUE))
    }
  }

  stop(
    "Variable '", name, "' introuvable dans le projet. ",
    "Verifie que la variable est bien definie dans un fichier R/ de ton projet.",
    call. = FALSE
  )
}

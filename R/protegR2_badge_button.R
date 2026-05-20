#' Bouton icone avec badge anime pour le header
#'
#' Cree un bouton icone avec un badge optionnel anime (messages, notifications).
#' Compatible avec n'importe quel header bslib (page_navbar, page_sidebarHL, etc.).
#'
#' Le badge peut etre mis a jour dynamiquement cote serveur avec
#' [protegr2_update_badge()].
#'
#' @param id Identifiant unique de ce bouton.
#' @param icon Tag icone. Utiliser [shiny::icon()].
#' @param count Compteur initial du badge. `NULL` = pas de badge. `0` = badge masque.
#' @param panel_id ID du [protegr2_dropdown_panel()] a ouvrir/fermer au clic.
#'   `NULL` desactive le toggle automatique.
#'
#' @return Un tag HTML.
#'
#' @export
protegr2_badge_button <- function(id, icon, count = NULL, panel_id = NULL) {
  show_badge <- !is.null(count) && count > 0L

  badge_tag <- if (show_badge) {
    htmltools::tags$span(class = "pr2-badge", count)
  }

  htmltools::tagList(
    htmltools::tags$div(
      class           = "pr2-badge-wrapper",
      `data-badge-id` = id,
      htmltools::tags$button(
        id           = paste0("pr2__badge__", id),
        class        = "pr2-header-btn",
        `data-panel` = panel_id,
        icon
      ),
      badge_tag
    ),
    protegr2_badge_dependency()
  )
}

#' Mettre a jour le badge d'un protegr2_badge_button
#'
#' Modifie dynamiquement le compteur affiche sur un [protegr2_badge_button()].
#'
#' @param session Objet session Shiny. Par defaut la session courante.
#' @param id L'`id` passe a [protegr2_badge_button()].
#' @param count Nouveau compteur. `0` ou `NULL` pour masquer le badge.
#'
#' @export
protegr2_update_badge <- function(session = shiny::getDefaultReactiveDomain(), id, count) {
  session$sendCustomMessage(
    "pr2_update_badge",
    list(id = id, count = count)
  )
}

#' Panneau dropdown pour le header
#'
#' Un panneau qui s'ouvre/se ferme au clic d'un [protegr2_badge_button()].
#' A placer dans le UI, par exemple dans le `...` de `page_sidebarHL()` ou dans
#' un `tagList()` apres le layout principal.
#'
#' Le lien avec le bouton se fait via `panel_id` dans [protegr2_badge_button()] :
#' le `panel_id` doit correspondre a l'`id` du `protegr2_dropdown_panel()`.
#'
#' @param id Identifiant HTML du panneau. Doit correspondre au `panel_id` du
#'   [protegr2_badge_button()] associe.
#' @param ... Contenu du panneau.
#' @param width Largeur du panneau en pixels. Defaut `280`.
#' @param align Alignement horizontal : `"right"` (defaut) ou `"left"`.
#'
#' @return Un tag HTML.
#'
#' @export
protegr2_dropdown_panel <- function(id, ..., width = 280, align = "right") {
  align <- match.arg(align, c("right", "left"))
  pos   <- if (align == "right") "right:12px;" else "left:12px;"

  htmltools::tags$div(
    id    = id,
    class = "pr2-dropdown-panel",
    style = paste0("width:", width, "px;", pos, "display:none;"),
    ...
  )
}

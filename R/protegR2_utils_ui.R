# ══════════════════════════════════════════════════════════════════════════════
# R/protegR2_utils_ui.R — Utilitaires UI exportés
# ══════════════════════════════════════════════════════════════════════════════
#
# Ce fichier regroupe les petites fonctions UI réutilisables dans plusieurs
# templates (sidebar, fluid, fixed, fillable...).
#
# Pourquoi ici plutôt que dans chaque template ?
#   Les templates sont des fichiers *copiés dans le projet utilisateur* — ils
#   ne font pas partie du package compilé. Si cette logique était dans les
#   templates, toute modification obligerait l'utilisateur à ré-copier ses
#   fichiers. En la gardant dans le package, un simple `devtools::load_all()`
#   (ou une mise à jour du package) suffit — les templates appellent la
#   fonction sans en embarquer le code.
# ══════════════════════════════════════════════════════════════════════════════


#' Contrôles de layout communs à plusieurs templates protegR2
#'
#' Retourne un `tagList()` contenant :
#'   - Le CSS qui masque les boutons fixes (logout + langue) rendus par
#'     `protegR2_ui()` / `protegR2_server()`. Ces boutons positionnés en
#'     `position: fixed` sont utiles dans les templates minimalistes (fixed,
#'     fillable) mais entrent en conflit avec les layouts qui placent ces
#'     éléments dans leur propre structure (sidebar, navbar, fluid).
#'   - Optionnellement, un bouton engrenage flottant pour ouvrir la modal
#'     de configuration (`open_config_modal`).
#'
#' @param gear Logical. `TRUE` (défaut) = inclure le bouton engrenage flottant.
#'   Mettre `FALSE` si le template gère la configuration autrement (ex : via
#'   un `nav_menu()` dans la navbar).
#'
#' @return Un `tagList` contenant les éléments HTML à inclure dans le rendu
#'   du template, typiquement au début du `tagList()` principal.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Dans un template UI (nécessite un contexte Shiny) :
#' tagList(
#'   protegr2_layout_controls(gear = TRUE),
#'   page_fluid(...)
#' )
#' }
protegr2_layout_controls <- function(gear = TRUE) {

  # ── CSS : masquer les boutons fixes de protegR2 ───────────────────────────
  #
  # protegR2_ui() rend deux éléments en position: fixed en haut à droite :
  #   - .protegr2-logout-fixed : le bouton « Se déconnecter »
  #   - .protegr2-idioma-fixed  : le sélecteur de langue
  #
  # Dans les templates qui placent ces éléments dans leur propre zone
  # (header flexbox, navbar, bas du sidebar), on les masque ici pour éviter
  # qu'ils se superposent au contenu.
  #
  # !important est requis car les styles inline de ces éléments ont une
  # priorité CSS élevée.
  hide_fixed <- tags$style(HTML("
    .protegr2-logout-fixed { display: none !important; }
    .protegr2-idioma-fixed  { display: none !important; }
  "))

  # ── Bouton engrenage flottant (optionnel) ─────────────────────────────────
  #
  # Placé en bas à droite de l'écran, z-index 9997 pour passer au-dessus
  # du contenu sans interférer avec les modals Bootstrap (z-index ~1050).
  #
  # L'inputId "open_config_modal" est écouté dans
  # protegR2_load_modules_servers.R — voir le bloc observeEvent dédié.
  #
  # Ce bouton est optionnel (gear = FALSE) pour les templates qui intègrent
  # la configuration directement dans leur navigation (ex: navbar via
  # nav_menu("Configuration")).
  gear_button <- if (gear) {
    tags$div(
      style = "position: fixed; bottom: 24px; right: 24px; z-index: 9997;",
      actionButton(
        inputId = "open_config_modal",
        label   = NULL,
        icon    = icon("gear"),
        class   = "btn btn-secondary",
        style   = "border-radius: 50%; width: 46px; height: 46px; padding: 0;",
        title   = "Configuration"
      )
    )
  }

  # ── Retour ────────────────────────────────────────────────────────────────
  # tagList() accepte NULL silencieusement — si gear = FALSE, gear_button est
  # NULL et tagList() l'ignore proprement. Pas besoin de if/else ici.
  tagList(hide_fixed, gear_button)
}


#' Dropdown de sélection de langue pour les templates protegR2
#'
#' Construit le bouton Bootstrap dropdown permettant à l'utilisateur de changer
#' la langue de l'interface. Retourne `NULL` si `config_global$show_idioma` est
#' `FALSE`, ce que `tagList()` ignore silencieusement.
#'
#' Les langues disponibles sont lues depuis `config_global$supported_idiomas`
#' (liste nommée définie dans `global.R`) — ajouter ou retirer une langue dans
#' `global.R` suffit, sans toucher aux templates ni à cette fonction.
#'
#' @param config_global Liste de configuration de l'application. Doit contenir :
#'   - `$show_idioma`      : logical, afficher ou non le sélecteur
#'   - `$supported_idiomas`: liste nommée `list(fr = list(mini_label, label), ...)`
#' @param idioma Character. Code de la langue courante (ex. `"fr"`, `"en"`).
#'   Typiquement `session$userData$idioma()` — le reactiveVal mis à jour par
#'   `observeEvent(input$select_idioma, ...)` dans `protegR2_server()`.
#'
#' @return Un `tags$div` Bootstrap dropdown, ou `NULL` si `show_idioma` est FALSE.
#'
#' @importFrom purrr imap
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Dans un template UI (nécessite un contexte Shiny + config_global chargé) :
#' lang_dropdown <- protegr2_lang_dropdown(config_global, session$userData$idioma())
#' }
protegr2_lang_dropdown <- function(config_global, idioma) {

  # ── Garde : sélecteur masqué ──────────────────────────────────────────────
  # Retourner NULL (et non tagList() vide) permet à l'appelant d'utiliser
  # lang_dropdown directement dans tagList() ou tags$div() sans condition
  # supplémentaire — Shiny/htmltools ignorent les NULL dans ces contextes.
  if (!(config_global$show_idioma %||% TRUE)) return(NULL)

  # ── Label affiché sur le bouton ───────────────────────────────────────────
  # On lit mini_label depuis supported_idiomas via le code langue courant.
  # Ex : idioma = "fr" → supported_idiomas[["fr"]]$mini_label → "FR"
  mini_label <- config_global$supported_idiomas[[idioma]]$mini_label

  # ── Dropdown Bootstrap ────────────────────────────────────────────────────
  # data-bs-toggle="dropdown" : active le comportement natif Bootstrap 5
  # (pas besoin de JS supplémentaire).
  #
  # Shiny.setInputValue avec {priority: 'event'} force le déclenchement
  # même si la langue sélectionnée est identique à la valeur courante —
  # sans cette option, Shiny ignorerait un clic sur la langue déjà active.
  tags$div(
    class = "dropdown",
    tags$button(
      class            = "btn btn-outline-secondary btn-sm dropdown-toggle",
      `data-bs-toggle` = "dropdown",
      `aria-expanded`  = "false",
      tagList(icon("globe"), " ", mini_label)
    ),
    # imap() passe simultanément le nom ("fr", "en"...) et la valeur
    # (list(mini_label, label)) — les deux sont nécessaires ici.
    tags$ul(
      class = "dropdown-menu dropdown-menu-end",
      purrr::imap(config_global$supported_idiomas, function(lang, ref) {
        tags$li(tags$a(
          class   = "dropdown-item",
          href    = "#",
          onclick = sprintf("Shiny.setInputValue('select_idioma', '%s', {priority: 'event'})", ref),
          lang$label
        ))
      })
    )
  )
}

print("protegR2_load_modules_UIs — style: fluid")

# Style "fluid" : conteneur pleine largeur (page_fluid), sans navigation
# intégrée. C'est le layout le plus simple — un header, un module, c'est tout.
# Si tu veux de la navigation, ajoute un navset_*() directement dans ton module
# ou après le header dans page_fluid().
#
# Logout + sélecteur de langue :
#   Intégrés dans un header flexbox en haut de la page.
#
# Configuration (⚙) : Bouton flottant pour accéder au menu de configuration

protegR2_load_modules_UIs <- function(session, tr) {

  role          <- session$userData$user_info$user_role()
  config_global <- session$userData$config_global
  req(role)

  # ── CSS masquant les boutons fixes + bouton engrenage flottant ───────────
  layout_controls <- protegr2_layout_controls(gear = TRUE) # CSS masquant boutons fixes + gear = TRUE pour menu config

  # ── Dropdown de sélection de langue ──────────────────────────────────────
  # Construit depuis config_global$supported_idiomas (défini dans global.R).
  # Retourne NULL si show_idioma est FALSE — ignoré silencieusement par tagList().
  lang_dropdown <- protegr2_lang_dropdown(config_global, session$userData$idioma())

  # ── Header : titre + langue + logout ──────────────────────────────────────
  # Bande en haut de la page, séparée du contenu par une bordure.
  header <- tags$div(
    class = "d-flex justify-content-between align-items-center py-2 mb-3 border-bottom",
    tags$span("Titre de l'application", class = "h5 mb-0"),
    tags$div(
      class = "d-flex gap-2 align-items-center",
      lang_dropdown,
      actionButton(
        inputId = "logout",
        label   = tagList(icon("right-from-bracket"), " ", tr("logout")),
        class   = "btn btn-outline-secondary btn-sm"
      )
    )
  )

  # ── Rendu : page_fluid ────────────────────────────────────────────────────
  # Conteneur Bootstrap pleine largeur, sans navigation intégrée.
  # Remplace mod_demo1_ui() par ton propre module.
  # Si tu veux de la navigation, ajoute un navset_*() directement ici
  # ou à l'intérieur de ton module.
  tagList(
    layout_controls,
    page_fluid(
      header,
      mod_demo1_ui("demo1", tr)
    )
  )
}

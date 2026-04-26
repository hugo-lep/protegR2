print("protegR2_load_modules_UIs — style: fillable")

# Style "fillable" : dashboard plein écran (page_fillable).
# Le contenu s'étend pour remplir toute la hauteur disponible du navigateur.
# Adapté aux dashboards avec graphiques ou tableaux plein écran.
# Si tu veux de la navigation, ajoute un navset_card_underline() dans ton module.
#
# Logout + sélecteur de langue :
#   Intégrés dans un header flexbox en haut de la page.
#   Le header prend sa hauteur naturelle — page_fillable() étire uniquement
#   le module en dessous pour occuper le reste du viewport.
#
# Configuration (⚙) : Bouton flottant pour accéder au menu de configuration

protegR2_load_modules_UIs <- function(session, tr) {

  role          <- session$userData$user_info$user_role()
  config_global <- session$userData$config_global
  req(role)

  # ── CSS masquant les boutons fixes + bouton engrenage flottant ───────────
  layout_controls <- protegr2_layout_controls(gear = TRUE)

  # ── Dropdown de sélection de langue ──────────────────────────────────────
  lang_dropdown <- protegr2_lang_dropdown(config_global, session$userData$idioma())

  # ── Header : titre + langue + logout ──────────────────────────────────────
  # Le header est un élément non-fillable — il prend sa hauteur naturelle.
  # page_fillable() étire uniquement les éléments fillable (le module ci-dessous).
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

  # ── Rendu : page_fillable ─────────────────────────────────────────────────
  # Remplace mod_fillable_ui() par ton propre module.
  # Si tu veux de la navigation, ajoute un navset_card_underline() directement
  # ici ou à l'intérieur de ton module.
  tagList(
    layout_controls,
    page_fillable(
      header,
      mod_fillable_ui("fillable_demo")
    )
  )
}

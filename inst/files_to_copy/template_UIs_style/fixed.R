print("protegR2_load_modules_UIs — style: fixed")

# Style "fixed" : page à largeur maximale fixe centrée (page_fixed).
# Adapté aux applications avec beaucoup de contenu texte ou formulaires.
# Si tu veux de la navigation, ajoute un navset_*() dans ton module.
#
# Logout + sélecteur de langue :
#   Intégrés dans un header flexbox en haut de la page.
#
# Configuration (⚙) : Bouton flottant pour accéder au menu de configuration

protegR2_load_modules_UIs <- function(session, tr) {

  role          <- session$userData$user_info$user_role()
  config_global <- session$userData$config_global
  req(role)

  # ── Backend ────────────────────────────────────────────────────────────────
  backend <- config_global$protegR2$user_config_backend %||% "none"

  # ── CSS masquant les boutons fixes + bouton engrenage flottant ───────────
  # gear = FALSE en mode local : les mots de passe sont codés en dur, afficher
  # l'engrenage de config donnerait une fausse impression de persistance.
  layout_controls <- protegr2_layout_controls(gear = backend != "local")

  # ── Dropdown de sélection de langue ──────────────────────────────────────
  lang_dropdown <- protegr2_lang_dropdown(config_global, session$userData$idioma())

  # ── Header : titre + langue + logout ──────────────────────────────────────
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

  # ── Rendu : page_fixed ────────────────────────────────────────────────────
  # Remplace mod_demo1_ui() par ton propre module.
  # Si tu veux de la navigation, ajoute un navset_*() directement ici
  # ou à l'intérieur de ton module.
  tagList(
    layout_controls,
    page_fixed(
      header,
      mod_demo1_ui("demo1", tr)
    )
  )
}

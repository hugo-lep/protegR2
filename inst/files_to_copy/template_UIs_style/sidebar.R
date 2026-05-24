print("protegR2_load_modules_UIs — style: sidebar")

# Style "sidebar" : page_sidebar() — layout à deux zones.
#   Sidebar gauche  → filtres, options, info persistentes
#   Zone principale → contenu réactif aux filtres
#
# C'est l'utilisation naturelle de page_sidebar() : les filtres vivent dans
# le sidebar, le résultat s'affiche à droite. Si tu veux des onglets dans
# la zone principale, place-les directement dans ton module UI principal —
# pas dans ce fichier template.
#
# Logout + sélecteur de langue :
#   Intégrés dans le header principal via flexbox (titre à gauche, contrôles
#
# Configuration (⚙) : Bouton flottant pour accéder au menu de configuration
#
# Paramètres du sidebar :
#   open  = "desktop" → ouvert sur desktop, fermé sur mobile (toggle Bootstrap)
#   width = 250        → largeur en pixels, ajustable

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
  # Construit depuis config_global$supported_idiomas (défini dans global.R).
  # Retourne NULL si show_idioma est FALSE — ignoré silencieusement par tagList().
  lang_dropdown <- protegr2_lang_dropdown(config_global, session$userData$idioma())

  # ── Header principal (titre + langue + logout) ────────────────────────────
  # page_sidebar(title = ...) accepte du HTML arbitraire — on en profite pour
  # placer langue et logout à droite du titre via flexbox.

  page_title <- tags$div(
    style = "display: flex; justify-content: space-between; align-items: center; width: 100%;",

    tags$span("Titre de la section principale"),

    tags$div(
      style = "display: flex; gap: 8px; align-items: center;",
      lang_dropdown,
      actionButton(
        inputId = "logout",
        label   = tagList(icon("right-from-bracket"), " ", tr("logout")),
        class   = "btn btn-outline-secondary btn-sm"
      )
    )
  )

  # ── Rendu : page_sidebar ───────────────────────────────────────────────────
  tagList(
    layout_controls,
    page_sidebar(
      title = page_title,

      sidebar = sidebar(
        open  = "desktop",
        width = 250,
        title = "Sidebar title",
        # ── Filtres ──────────────────────────────────────────────────────────
        # Remplace mod_demo_sidebar_filter_ui() par ton propre module de filtres.
        mod_demo_sidebar_filter_ui("sidebar_demo")
      ),

      # ── Zone principale ───────────────────────────────────────────────────
      # Remplace mod_demo_sidebar_content_ui() par ton propre module de contenu.
      # Si tu veux des onglets, utilise navset_*() directement dans ce module.
      mod_demo_sidebar_content_ui("sidebar_demo")

    )
  )
}

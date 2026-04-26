print("protegR2_load_modules_UIs — style: fillable")

# Style "fillable" : dashboard plein écran (page_fillable), chaque panel
# s'étend pour remplir la hauteur disponible du navigateur.
# Les onglets sont présentés dans des cards avec soulignement (navset_card_underline).
# Adapté aux dashboards avec graphiques, cartes ou tableaux plein écran.
#
# Logout + sélecteur de langue :
#   Intégrés dans un header flexbox en haut de la page.
#   Le header prend sa hauteur naturelle — page_fillable() étire uniquement
#   le navset_card_underline en dessous pour occuper le reste du viewport.
#
# Configuration (⚙) : Bouton flottant pour accéder au menu de configuration
#
# Convention obligatoire : id = "nav_tab" sur le navset_card_underline().

protegR2_load_modules_UIs <- function(session, tr) {

  selected      <- isolate(getQueryString(session))$page %||% "home"
  role          <- session$userData$user_info$user_role()
  config_global <- session$userData$config_global
  req(role)

  # ── CSS masquant les boutons fixes + bouton engrenage flottant ───────────
  layout_controls <- protegr2_layout_controls(gear = TRUE)

  # ── Dropdown de sélection de langue ──────────────────────────────────────
  lang_dropdown <- protegr2_lang_dropdown(config_global, session$userData$idioma())

  # ── Header : titre + langue + logout ──────────────────────────────────────
  # Le header est un élément non-fillable — il prend sa hauteur naturelle.
  # page_fillable() étire uniquement les éléments fillable (le navset ci-dessous).
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

  # ── Panneaux principaux (sans configuration — celle-ci est dans le modal) ──

  panels <- list(

    nav_panel(title = tr("menu1_sidebar_type_access"),
              value = "home",
              icon  = icon("house"),
              mod_fillable_ui("fillable_demo")),

    nav_panel(title = tr("menu2_module_demo"),
              value = "demo",
              icon  = icon("chart-bar"),
              mod_demo1_ui("demo1", tr)),

    nav_menu(title = tr("subItem_test"),
             icon  = icon("folder"),
      nav_panel(title = tr("subitem1"), value = "subitem1", mod_demo_subitem1_ui("subitem1")),
      nav_panel(title = tr("subitem2"), value = "subitem2", mod_demo_airplane_ui("turn_plane"))
    )

  )

  # ── Rendu : page_fillable + navset_card_underline ─────────────────────────
  # page_fillable() étire chaque panel pour occuper toute la hauteur viewport.
  # navset_card_underline() : onglets dans une card avec soulignement de l'actif.
  tagList(
    layout_controls,
    page_fillable(
      header,
      do.call(navset_card_underline, c(
        list(id = "nav_tab", selected = selected),
        panels
      ))
    )
  )
}


# ══════════════════════════════════════════════════════════════════════════════
# À ajouter dans protegR2_load_modules_servers.R
# ══════════════════════════════════════════════════════════════════════════════
#
# observeEvent(input_main_app$open_config_modal, {
#   role <- main_session$userData$user_info$user_role()
#
#   config_panels <- list(
#     nav_panel("Votre compte", value = "your_account", mod_config_ui1("config"))
#   )
#   if (role %in% c("admin", "super_admin", "dev")) {
#     config_panels <- c(config_panels, list(
#       nav_panel("Administration", value = "admin_access", mod_config_ui2("config"))
#     ))
#   }
#   if (role %in% c("super_admin", "dev")) {
#     config_panels <- c(config_panels, list(
#       nav_panel("Super Admin", value = "super_admin_access", mod_config_ui3("config"))
#     ))
#   }
#   if (role == "dev") {
#     config_panels <- c(config_panels, list(
#       nav_panel("Dev", value = "dev_access", mod_config_ui4("config"))
#     ))
#   }
#
#   showModal(modalDialog(
#     title     = tagList(icon("gear"), " Configuration"),
#     do.call(navset_tab, config_panels),
#     size      = "l",
#     easyClose = TRUE,
#     footer    = modalButton("Fermer")
#   ))
# })

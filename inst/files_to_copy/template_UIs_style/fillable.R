print("protegR2_load_modules_UIs — style: fillable")

# Ce fichier est copié dans R/ de ton projet par protegR2_init_layout("fillable").
# C'est ici que tu branches tes propres modules Shiny.
#
# Style "fillable" : dashboard plein écran (page_fillable), chaque panel
# s'étend pour remplir la hauteur disponible du navigateur.
# Les onglets sont présentés dans des cards avec soulignement (navset_card_underline).
# Adapté aux dashboards avec graphiques, cartes ou tableaux plein écran.
#
# Configuration (⚙) :
#   Même mécanique que le style "fixed" : bouton engrenage flottant + modal.
#   Voir le bloc commenté à la fin de ce fichier pour le code serveur.
#
# Convention obligatoire : id = "nav_tab" sur le navset_card_underline().

protegR2_load_modules_UIs <- function(session, tr) {

  selected <- isolate(getQueryString(session))$page
  role     <- session$userData$user_info$user_role()
  req(role)

  # ── Panneaux principaux (sans configuration — celle-ci est dans le modal) ──

  panels <- list(

    nav_panel(title = tr("menu1_sidebar_type_access"),
              value = "home",
              icon  = icon("house"),
              mod_demo2_ui("demo2", session = session)),

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

  # ── Bouton engrenage flottant ──────────────────────────────────────────────
  # Même logique que le style "fixed". z-index 9997 : sous logout (9998).
  gear_button <- tags$div(
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

  # ── Rendu : page_fillable + navset_card_underline ─────────────────────────
  # page_fillable() étire chaque panel pour occuper toute la hauteur viewport.
  # navset_card_underline() : onglets dans une card avec soulignement de l'actif.
  # fillable = TRUE sur navset_card_underline : le contenu de chaque panel
  # s'étire aussi pour remplir la card — idéal pour les graphiques plein écran.
  tagList(
    gear_button,
    page_fillable(
      do.call(navset_card_underline, c(
        list(id = "nav_tab", selected = selected, fillable = TRUE),
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

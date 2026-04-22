print("protegR2_load_modules_UIs — style: fixed")

# Ce fichier est copié dans R/ de ton projet par protegR2_init_layout("fixed").
# C'est ici que tu branches tes propres modules Shiny.
#
# Style "fixed" : page à largeur maximale fixe centrée (page_fixed),
# avec onglets horizontaux classiques (navset_tab).
# Adapté aux applications avec beaucoup de contenu texte ou formulaires.
#
# Configuration (⚙) :
#   Le bouton engrenage flottant (bas droite) déclenche un modal de configuration.
#   Les panneaux de config ne sont PAS dans le navset principal — ils vivent
#   dans le modal, accessible uniquement depuis ce bouton.
#
#   La logique serveur du modal (observeEvent + showModal) doit être ajoutée
#   dans protegR2_load_modules_servers.R — voir le bloc commenté à la fin
#   de ce fichier.
#
# Convention obligatoire : id = "nav_tab" sur le navset_tab().

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
  # Positionné en bas à droite, z-index sous le bouton logout (z-index 9998).
  # Déclenche input$open_config_modal — observé dans protegR2_load_modules_servers.R.
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

  # ── Rendu : page_fixed + navset_tab ───────────────────────────────────────
  # page_fixed() centre le contenu avec une largeur maximale (~1140px).
  # navset_tab() affiche les onglets horizontaux classiques Bootstrap.
  # tagList() combine le bouton flottant et la page — les deux sont rendus
  # dans le même uiOutput("main_ui") de protegR2_server.
  tagList(
    gear_button,
    page_fixed(
      do.call(navset_tab, c(
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
# Ce bloc gère le modal de configuration déclenché par le bouton engrenage.
# À coller dans la fonction protegR2_load_modules_servers(), qui reçoit
# input_main_app et main_session.
#
# Les modules de config (mod_config_server) doivent rester initialisés
# au démarrage — le modal affiche leur UI, pas leur serveur.
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

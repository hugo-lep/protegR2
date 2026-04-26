print("protegR2_load_modules_UIs — style: fixed")

# Style "fixed" : page à largeur maximale fixe centrée (page_fixed),
# avec onglets horizontaux classiques (navset_tab).
# Adapté aux applications avec beaucoup de contenu texte ou formulaires.
#
# Logout + sélecteur de langue :
#   Intégrés dans un header flexbox en haut de la page.
#
# Configuration (⚙) : Bouton flottant pour accéder au menu de configuration
#
# Convention obligatoire : id = "nav_tab" sur le navset_tab().

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

  # ── Rendu : page_fixed + navset_tab ───────────────────────────────────────
  # page_fixed() centre le contenu avec une largeur maximale (~1140px).
  # navset_tab() affiche les onglets horizontaux classiques Bootstrap.
  tagList(
    layout_controls,
    page_fixed(
      header,
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

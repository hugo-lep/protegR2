print("protegR2_load_modules_UIs — style: navbar")

# Ce fichier est copié dans R/ de ton projet par protegR2_init_layout("navbar").
# C'est ici que tu branches tes propres modules Shiny.
#
# Style "navbar" : barre de navigation horizontale en haut (page_navbar).
# La barre collapse automatiquement en icône hamburger sur mobile (Bootstrap natif).
#
# Personnalisation de la barre :
#   title  : texte affiché à gauche (lu depuis config_global$header_title).
#   bg     : couleur de fond de la barre (ex. "#2c3e50", ou NULL pour le thème).
#   inverse: TRUE = texte blanc sur fond sombre, FALSE = texte sombre sur fond clair.
#   underline : TRUE = soulignement de l'onglet actif.
#
# Note architecturale :
#   page_navbar() est rendu à l'intérieur du renderUI de protegR2_server,
#   lui-même dans un page_fluid(). Le thème Bootstrap est déjà appliqué par
#   protegR2_ui() — page_navbar() n'a pas besoin de son propre thème.
#
# Convention obligatoire : id = "nav_tab" sur le page_navbar().

protegR2_load_modules_UIs <- function(session, tr) {

  selected      <- isolate(getQueryString(session))$page
  role          <- session$userData$user_info$user_role()
  config_global <- session$userData$config_global
  req(role)

  # ── Panneaux principaux ────────────────────────────────────────────────────

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

  # ── Panneaux de configuration ──────────────────────────────────────────────

  config_panels <- list(
    nav_panel(title = tr("your_account"), value = "your_account", mod_config_ui1("config"))
  )

  if (role %in% c("admin", "super_admin", "dev")) {
    config_panels <- c(config_panels, list(
      nav_panel(title = tr("admin_access"), value = "admin_access", mod_config_ui2("config"))
    ))
  }

  if (role %in% c("super_admin", "dev")) {
    config_panels <- c(config_panels, list(
      nav_panel(title = tr("super_admin_access"), value = "super_admin_access", mod_config_ui3("config"))
    ))
  }

  if (role == "dev") {
    config_panels <- c(config_panels, list(
      nav_panel(title = tr("dev_access"), value = "dev_access", mod_config_ui4("config"))
    ))
  }

  panels <- c(panels, list(
    do.call(nav_menu, c(
      list(title = tr("configuration"), icon = icon("gear")),
      config_panels
    ))
  ))

  # ── Rendu : page_navbar ────────────────────────────────────────────────────
  # do.call() permet de passer une liste de longueur variable à page_navbar().
  # title       : texte à gauche de la barre — lu depuis config_global.
  # id          : obligatoire pour la restauration d'onglet via l'URL.
  # collapsible : TRUE = hamburger sur mobile (comportement Bootstrap natif).
  # underline   : TRUE = soulignement de l'onglet actif.
  do.call(page_navbar, c(
    list(
      title       = config_global$header_title %||% "Application",
      id          = "nav_tab",
      selected    = selected,
      underline   = TRUE,
      collapsible = TRUE
    ),
    panels
  ))
}

print("protegR2_load_modules_UIs — style: sidebar")

# Ce fichier est copié dans R/ de ton projet par protegR2_init_layout("sidebar").
# C'est ici que tu branches tes propres modules Shiny.
#
# Style "sidebar" : page_sidebar() avec navigation verticale dans un panneau
# latéral foldable. Le sidebar peut être fermé/ouvert via le bouton toggle.
#
# Architecture nav/contenu :
#   page_sidebar() ne "split" pas automatiquement nav et contenu comme le fait
#   navset_pill_list(). On utilise deux navsets complémentaires :
#
#   1. navset_pill(id = "nav_tab") dans le sidebar  → affiche les pills, pas de contenu
#   2. navset_hidden(id = "nav_content") en zone principale → affiche le contenu
#
#   Un observeEvent dans protegR2_load_modules_servers.R synchronise les deux
#   quand l'utilisateur clique une pill :
#     observeEvent(input_main_app$nav_tab, {
#       nav_select("nav_content", input_main_app$nav_tab, session = main_session)
#     })
#
# Convention obligatoire :
#   - id = "nav_tab" sur le navset_pill → protegR2_server met à jour l'URL
#   - id = "nav_content" sur le navset_hidden → synchronisé côté serveur
#   - Les value= doivent être identiques entre les deux navsets

protegR2_load_modules_UIs <- function(session, tr) {

  selected <- isolate(getQueryString(session))$page
  role     <- session$userData$user_info$user_role()
  req(role)

  # ── Pills de navigation (sidebar) — contenu NULL ───────────────────────────
  # Chaque nav_panel ici n'a PAS de contenu (juste title + value).
  # Le tab-content vide est masqué par le CSS ci-dessous.
  # Les value= doivent correspondre exactement à ceux du navset_hidden.

  config_nav <- list(
    nav_panel(title = tr("your_account"), value = "your_account")
  )
  if (role %in% c("admin", "super_admin", "dev")) {
    config_nav <- c(config_nav, list(
      nav_panel(title = tr("admin_access"), value = "admin_access")
    ))
  }
  if (role %in% c("super_admin", "dev")) {
    config_nav <- c(config_nav, list(
      nav_panel(title = tr("super_admin_access"), value = "super_admin_access")
    ))
  }
  if (role == "dev") {
    config_nav <- c(config_nav, list(
      nav_panel(title = tr("dev_access"), value = "dev_access")
    ))
  }

  # ── Panneaux de contenu (zone principale — navset_hidden) ─────────────────
  # Les value= doivent correspondre exactement aux pills ci-dessus.

  content_panels <- list(
    nav_panel(value = "home",     mod_demo2_ui("demo2", session = session)),
    nav_panel(value = "demo",     mod_demo1_ui("demo1", tr)),
    nav_panel(value = "subitem1", mod_demo_subitem1_ui("subitem1")),
    nav_panel(value = "subitem2", mod_demo_airplane_ui("turn_plane")),
    nav_panel(value = "your_account", mod_config_ui1("config"))
  )
  if (role %in% c("admin", "super_admin", "dev")) {
    content_panels <- c(content_panels, list(
      nav_panel(value = "admin_access", mod_config_ui2("config"))
    ))
  }
  if (role %in% c("super_admin", "dev")) {
    content_panels <- c(content_panels, list(
      nav_panel(value = "super_admin_access", mod_config_ui3("config"))
    ))
  }
  if (role == "dev") {
    content_panels <- c(content_panels, list(
      nav_panel(value = "dev_access", mod_config_ui4("config"))
    ))
  }

  # ── Rendu ──────────────────────────────────────────────────────────────────
  page_sidebar(

    sidebar = sidebar(
      open  = "desktop",   # ouvert sur desktop, fermé sur mobile
      width = 250,         # largeur du sidebar en pixels

      # CSS : pills en colonne verticale + masquer la zone de contenu vide
      # que navset_pill génère automatiquement (tab-content sans enfants visibles).
      tags$style(HTML("
        #nav_tab.nav-pills          { flex-direction: column; gap: 2px; }
        #nav_tab ~ .tab-content     { display: none; }
      ")),

      # navset_pill définit input$nav_tab :
      #   → protegR2_server l'écoute pour mettre à jour l'URL (?page=...)
      #   → protegR2_load_modules_servers.R l'écoute pour sync le contenu
      do.call(navset_pill, c(
        list(id = "nav_tab", selected = selected),
        list(
          nav_panel(
            title = tagList(icon("house"), " ", tr("menu1_sidebar_type_access")),
            value = "home"
          ),
          nav_panel(
            title = tagList(icon("chart-bar"), " ", tr("menu2_module_demo")),
            value = "demo"
          ),
          do.call(nav_menu, c(
            list(title = tagList(icon("folder"), " ", tr("subItem_test"))),
            list(
              nav_panel(title = tr("subitem1"), value = "subitem1"),
              nav_panel(title = tr("subitem2"), value = "subitem2")
            )
          )),
          do.call(nav_menu, c(
            list(title = tagList(icon("gear"), " ", tr("configuration"))),
            config_nav
          ))
        )
      ))
    ),

    # Zone de contenu principale.
    # navset_hidden : affiche le contenu du panel sélectionné sans afficher
    # de tabs. La sélection est pilotée par nav_select() côté serveur.
    # selected = selected restaure l'onglet actif depuis l'URL au chargement.
    do.call(navset_hidden, c(
      list(id = "nav_content", selected = selected),
      content_panels
    ))

  )
}


# ══════════════════════════════════════════════════════════════════════════════
# À ajouter dans protegR2_load_modules_servers.R
# ══════════════════════════════════════════════════════════════════════════════
#
# Ce bloc synchronise le contenu (navset_hidden) avec la navigation (navset_pill).
# Sans lui, cliquer une pill ne change pas le contenu affiché.
#
# observeEvent(input_main_app$nav_tab, {
#   nav_select("nav_content", input_main_app$nav_tab, session = main_session)
# }, ignoreNULL = TRUE)

print("protegR2_load_modules_UIs — style: sidebarHL")

# Ce fichier est copié dans R/ de ton projet par protegR2_init_layout("sidebarHL").
# C'est ici que tu branches tes propres modules Shiny.
#
# Style "sidebarHL" : sidebar de navigation multi-pages via bslibHL::page_sidebarHL().
# Contrairement au style "sidebar" (page_sidebar de bslib), ce layout gère nativement
# la navigation entre pages — chaque hl_nav_panel() est à la fois un item de menu
# et son contenu associé.
#
# protegR2_compat = TRUE :
#   Remplace l'appel à protegr2_layout_controls() des autres templates.
#   page_sidebarHL() injecte lui-même le CSS qui masque les boutons fixes de
#   protegR2 (.protegr2-logout-fixed et .protegr2-idioma-fixed).
#   Ne pas appeler protegr2_layout_controls() ici — cela doublerait le CSS.
#
# Logout + sélecteur de langue :
#   Intégrés dans le header via le paramètre header_items = list(...).
#   Les versions "fixed" rendues par protegR2_ui() / protegR2_server() sont
#   masquées automatiquement par protegR2_compat = TRUE.
#
#   Note sur les IDs dupliqués :
#     logout        → même inputId que le bouton fixe — les deux déclenchent
#                     le même observeEvent côté serveur, sans conflit.
#     select_idioma → même inputId que le sélecteur fixe — celui-ci étant
#                     masqué, seul le header_item est interactif.
#
# Configuration :
#   Intégrée directement dans la navigation via hl_nav_group("Configuration").
#   Pas de bouton engrenage flottant — la sidebar est l'endroit naturel pour ça.
#   → Dans protegR2_load_modules_servers.R, le bloc observeEvent(open_config_modal)
#     n'est PAS nécessaire pour ce style. Il peut être supprimé sans risque.
#
# Restauration de l'onglet actif :
#   selected = page_actif lit le paramètre ?page= de l'URL.
#   L'observeEvent(input$nav_tab, ...) dans protegR2_server() maintient ce
#   paramètre à jour à chaque navigation.
#   Convention obligatoire : id = "nav_tab" sur page_sidebarHL().

protegR2_load_modules_UIs <- function(session, tr) {

  # ── Restauration de l'onglet actif depuis l'URL ───────────────────────────
  # isolate() évite une dépendance réactive sur getQueryString().
  # %||% "home" : si ?page= est absent (premier chargement), ouvrir "home".
  page_actif    <- isolate(shiny::getQueryString(session))$page %||% "home"

  role          <- session$userData$user_info$user_role()
  config_global <- session$userData$config_global
  req(role)

  # ── Dropdown de sélection de langue ──────────────────────────────────────
  # Retourne NULL si lang_choice est FALSE — ignoré silencieusement par list().
  lang_dropdown <- protegr2_lang_dropdown(config_global, session$userData$idioma())

  # ── Panneaux de configuration (selon le rôle) ─────────────────────────────
  # Tous les utilisateurs voient "Votre compte".
  # Les rôles élevés voient les panneaux supplémentaires.
  config_panels <- list(
    bslibHL::hl_nav_panel(
      title = tr("your_account"),
      value = "your_account",
      icon  = shiny::icon("user"),
      mod_config_ui1("config")
    )
  )

  if (role %in% c("admin", "super_admin", "dev")) {
    config_panels <- c(config_panels, list(
      bslibHL::hl_nav_panel(
        title = tr("admin_access"),
        value = "admin_access",
        icon  = shiny::icon("users-gear"),
        mod_config_ui2("config")
      )
    ))
  }

  if (role %in% c("super_admin", "dev")) {
    config_panels <- c(config_panels, list(
      bslibHL::hl_nav_panel(
        title = tr("super_admin_access"),
        value = "super_admin_access",
        icon  = shiny::icon("shield-halved"),
        mod_config_ui3("config")
      )
    ))
  }

  if (role == "dev") {
    config_panels <- c(config_panels, list(
      bslibHL::hl_nav_panel(
        title = tr("dev_access"),
        value = "dev_access",
        icon  = shiny::icon("code"),
        mod_config_ui4("config")
      )
    ))
  }

  # ── Rendu : page_sidebarHL ─────────────────────────────────────────────────
  # do.call() permet de passer les config_panels de longueur variable.
  # title  : lu depuis config_global — modifie-le dans global.R / S3.
  # id     : "nav_tab" — obligatoire pour la restauration d'onglet via l'URL
  #          (observeEvent(input$nav_tab, ...) dans protegR2_server()).
  do.call(bslibHL::page_sidebarHL, c(
    list(
      title           = config_global$protegR2$header_title %||% "Application",
      id              = "nav_tab",
      theme           = bslibHL::hl_theme(),
      protegR2_compat = TRUE,
      selected        = page_actif,

      # ── Items du header ──────────────────────────────────────────────────
      # Placez ici les éléments à afficher à droite dans la barre de titre.
      # L'ordre de la liste détermine l'ordre d'affichage (gauche → droite).
      header_items = list(

        # Sélecteur de langue — NULL si lang_choice est FALSE (ignoré par list())
        lang_dropdown,

        # ── [OPTIONNEL] Bouton messages avec badge animé ──────────────────
        # Décommenter si votre app a un système de messagerie.
        # Mettre à jour le compteur depuis le serveur via protegr2_update_badge().
        # protegR2::protegr2_badge_button(
        #   id       = "msg",
        #   icon     = shiny::icon("envelope"),
        #   count    = 0,
        #   panel_id = "msg_panel"
        # ),

        # ── [OPTIONNEL] Bouton notifications avec badge animé ─────────────
        # Décommenter si votre app a un système de notifications.
        # protegR2::protegr2_badge_button(
        #   id       = "notif",
        #   icon     = shiny::icon("bell"),
        #   count    = 0,
        #   panel_id = "notif_panel"
        # ),

        # Bouton logout
        shiny::actionButton(
          inputId = "logout",
          label   = shiny::tagList(shiny::icon("right-from-bracket"), " ", tr("logout")),
          class   = "pr2-header-btn btn-sm"
        )
      )
    ),

    # ── Pages de navigation principales ────────────────────────────────────
    # Remplace les mod_demo*_ui() par tes propres modules.
    # Chaque hl_nav_panel() = un item dans la sidebar + son contenu.
    list(
      bslibHL::hl_nav_panel(
        title = tr("menu1_sidebar_type_access"),
        value = "home",
        icon  = shiny::icon("house"),
        mod_demo2_ui("demo2", session = session)
      ),

      bslibHL::hl_nav_panel(
        title = tr("menu2_module_demo"),
        value = "demo",
        icon  = shiny::icon("chart-bar"),
        mod_demo1_ui("demo1", tr)
      ),

      # ── Exemple de groupe collapsible ──────────────────────────────────
      # Un hl_nav_group() crée une section repliable dans la sidebar.
      # Décommenter et adapter à tes besoins.
      # do.call(bslibHL::hl_nav_group, c(
      #   list(title = tr("subItem_test"), icon = shiny::icon("folder")),
      #   list(
      #     bslibHL::hl_nav_panel(title = tr("subitem1"), value = "subitem1",
      #                           mod_demo_subitem1_ui("subitem1")),
      #     bslibHL::hl_nav_panel(title = tr("subitem2"), value = "subitem2",
      #                           mod_demo_airplane_ui("turn_plane"))
      #   )
      # )),

      # ── Groupe de configuration ─────────────────────────────────────────
      # Toujours en dernier — section repliable dans la sidebar.
      # do.call() permet de passer config_panels de longueur variable.
      do.call(bslibHL::hl_nav_group, c(
        list(title = tr("configuration"), icon = shiny::icon("gear")),
        config_panels
      ))
    ),

    # ── Panneaux dropdown [OPTIONNEL] ───────────────────────────────────────
    # À décommenter uniquement si tu utilises les badge buttons ci-dessus.
    # Ces panneaux s'affichent en overlay sous le bouton correspondant.
    # list(
    #   protegR2::protegr2_dropdown_panel(
    #     id = "msg_panel",
    #     shiny::h5(shiny::icon("envelope"), " ", tr("messages")),
    #     shiny::p(tr("no_messages"))
    #   ),
    #   protegR2::protegr2_dropdown_panel(
    #     id = "notif_panel",
    #     shiny::h5(shiny::icon("bell"), " ", tr("notifications")),
    #     shiny::p(tr("no_notifications"))
    #   )
    # )

    list()  # Retirer cette ligne si tu décommentes les dropdown panels ci-dessus
  ))
}

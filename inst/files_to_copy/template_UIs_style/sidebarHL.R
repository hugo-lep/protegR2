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
#   La synchronisation URL est gérée par page_sidebarHL_server() dans
#   protegR2_load_modules_servers.R (via input$hl__nav, interne à bslibHL).
#   L'observeEvent(input$nav_tab, ...) de protegR2_server() ne s'applique
#   PAS à ce layout — page_sidebarHL() n'expose pas d'input$nav_tab.

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

  # ── Backend ────────────────────────────────────────────────────────────────
  backend <- config_global$protegR2$user_config_backend %||% "none"

  # ── Panneaux de configuration (selon le rôle) ─────────────────────────────
  # Masqués en mode local : les mots de passe et utilisateurs sont définis dans
  # protegR2_local_users.R — l'interface de gestion ne ferait rien d'utile et
  # donnerait une fausse impression que les changements sont persistés.
  #
  # En mode s3 / postgres : tous les utilisateurs voient "Votre compte",
  # les rôles élevés voient les panneaux supplémentaires selon leur niveau.
  config_panels <- if (backend == "local") {
    NULL
  } else {
    panels <- list(
      bslibHL::hl_nav_panel(
        title = tr("your_account"),
        value = "your_account",
        icon  = shiny::icon("user"),
        mod_config_ui1("config")
      )
    )
    if (role %in% c("admin", "super_admin", "dev")) {
      panels <- c(panels, list(
        bslibHL::hl_nav_panel(
          title = tr("admin_access"),
          value = "admin_access",
          icon  = shiny::icon("users-gear"),
          mod_config_ui2("config")
        )
      ))
    }
    if (role %in% c("super_admin", "dev")) {
      panels <- c(panels, list(
        bslibHL::hl_nav_panel(
          title = tr("super_admin_access"),
          value = "super_admin_access",
          icon  = shiny::icon("shield-halved"),
          mod_config_ui3("config")
        )
      ))
    }
    if (role == "dev") {
      panels <- c(panels, list(
        bslibHL::hl_nav_panel(
          title = tr("dev_access"),
          value = "dev_access",
          icon  = shiny::icon("code"),
          mod_config_ui4("config")
        )
      ))
    }
    panels
  }

  # ── Rendu : page_sidebarHL ─────────────────────────────────────────────────
  # do.call() permet de passer les nav_panels de longueur variable.
  #
  # title : reçoit un tag HTML construit avec les classes CSS bslibHL.
  #   page_sidebarHL() n'a pas de paramètre header_items — les éléments du
  #   header (boutons, sélecteur de langue) doivent être embarqués dans title.
  #   Structure attendue :
  #     hl-header-wrapper  → div flex row sur toute la largeur du header
  #     hl-header-title    → span qui prend l'espace restant (flex: 1)
  #     hl-header-items    → div flex-shrink-0 pour les boutons à droite
  #
  # protegR2_compat = TRUE : masque .protegr2-logout-fixed et
  #   .protegr2-idioma-fixed injectés par protegR2_ui(). Sans ce paramètre,
  #   ces boutons "fixed" se superposeraient aux boutons du header bslibHL.
  #
  # selected : restaure l'onglet actif depuis l'URL (?page=valeur).
  #   La mise à jour de l'URL à chaque navigation est gérée par
  #   page_sidebarHL_server() appelé dans protegR2_load_modules_servers.R.
  do.call(bslibHL::page_sidebarHL, c(
    list(
      title = htmltools::tags$div(
        class = "hl-header-wrapper",

        # Titre texte de l'application — flex: 1, prend tout l'espace disponible
        htmltools::tags$span(
          class = "hl-header-title",
          config_global$protegR2$header_title %||% "Application"
        ),

        # Éléments à droite dans le header — flex-shrink: 0
        htmltools::tags$div(
          class = "hl-header-items",

          # Sélecteur de langue — NULL si lang_choice est FALSE (ignoré silencieusement)
          lang_dropdown,

          # ── [OPTIONNEL] Bouton messages avec badge animé ────────────────
          # Décommenter si votre app a un système de messagerie.
          # Mettre à jour le compteur depuis le serveur via protegr2_update_badge().
          # protegR2::protegr2_badge_button(
          #   id       = "msg",
          #   icon     = shiny::icon("envelope"),
          #   count    = 0,
          #   panel_id = "msg_panel"
          # ),

          # ── [OPTIONNEL] Bouton notifications avec badge animé ───────────
          # Décommenter si votre app a un système de notifications.
          # protegR2::protegr2_badge_button(
          #   id       = "notif",
          #   icon     = shiny::icon("bell"),
          #   count    = 0,
          #   panel_id = "notif_panel"
          # ),

          # Bouton logout — même inputId "logout" que le bouton fixed masqué
          # par protegR2_compat = TRUE. Les deux déclenchent le même observeEvent.
          shiny::actionButton(
            inputId = "logout",
            label   = shiny::tagList(shiny::icon("right-from-bracket"), " ", tr("logout")),
            class   = "pr2-header-btn btn-sm"
          )
        )
      ),

      theme           = bslibHL::hl_theme(),
      protegR2_compat = TRUE,
      selected        = page_actif
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
      # NULL en mode local : config_panels est NULL, le groupe n'est pas rendu.
      if (!is.null(config_panels))
        do.call(bslibHL::hl_nav_group, c(
          list(title = tr("configuration"), icon = shiny::icon("gear")),
          config_panels
        ))
    ),

    # ── Panneaux dropdown [OPTIONNEL] ───────────────────────────────────────
    # À décommenter uniquement si tu utilises les badge buttons dans hl-header-items.
    # Ces panneaux s'affichent en overlay sous le bouton correspondant.
    # Ils sont passés dans ... de page_sidebarHL() — pas dans title.
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

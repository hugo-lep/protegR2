print("protegR2_load_modules_servers")

# ══════════════════════════════════════════════════════════════════════════════
# protegR2_load_modules_servers()
#
# Point d'entrée pour initialiser tous les modules Shiny côté serveur.
# Cette fonction est appelée par protegR2_server() juste après que l'utilisateur
# est authentifié.
#
# Paramètres :
#   sessions        — environnement global qui trace les sessions actives
#   input_main_app  — objet input de la session principale (passé depuis protegR2_server)
#   main_session    — objet session de la session principale
#
# Convention pour les modules de config : passer sessions, input_main_app et
# main_session à mod_config_server() afin qu'il puisse gérer les comptes,
# réinitialiser des mots de passe, etc.
# ══════════════════════════════════════════════════════════════════════════════

protegR2_load_modules_servers <- function(sessions,
                                          input_main_app,
                                          main_session) {

  # ── Modules principaux ─────────────────────────────────────────────────────

  mod_demo1_server("demo1")
  mod_demo_subitem1_server("subitem1")
  mod_demo_airplane_server("turn_plane")
  mod_fillable_server("fillable_demo")
  mod_demo_sidebar_server("sidebar_demo")

  # ── Module de configuration ────────────────────────────────────────────────
  # Reçoit sessions et main_session pour gérer les utilisateurs et les rôles.

  mod_config_server("config",
                    sessions       = sessions,
                    input_main_app = input_main_app,
                    main_session   = main_session)

  # ── Synchronisation nav sidebar ────────────────────────────────────────────
  #
  # Uniquement actif pour le style "sidebar" (page_sidebar + navset_pill +
  # navset_hidden). Pour les autres styles (navbar, fixed, fillable), l'élément
  # "nav_content" n'existe pas côté client — nav_select() envoie un message qui
  # est simplement ignoré, sans erreur.
  #
  # Pourquoi deux navsets dans le style sidebar ?
  #   page_sidebar() ne "split" pas automatiquement nav et contenu.
  #   On utilise navset_pill(id = "nav_tab") dans le sidebar pour afficher les
  #   onglets (sans contenu), et navset_hidden(id = "nav_content") en zone
  #   principale pour afficher le contenu. Cet observateur synchronise les deux :
  #   quand l'utilisateur clique un pill → input_main_app$nav_tab change →
  #   on sélectionne le même panel dans nav_content.
  #
  # ignoreNULL = TRUE : évite un déclenchement au démarrage quand nav_tab
  # vaut NULL (avant que l'UI ne soit rendue).

  observeEvent(input_main_app$nav_tab, {
    nav_select("nav_content", input_main_app$nav_tab, session = main_session)
  }, ignoreNULL = TRUE)


  # ── Modal de configuration — styles "fixed" et "fillable" uniquement ────────
  #
  # ⚠️  SUPPRIMER CE BLOC si ton style est "sidebar", "navbar" ou "fluid".
  #     Ces styles intègrent la configuration directement dans le navset.
  #     Ce bloc n'a d'effet que si le template UI contient un bouton engrenage
  #     avec inputId = "open_config_modal".
  #
  # Pourquoi un modal plutôt qu'un onglet dans le navset ?
  #   page_fixed() et page_fillable() ont une zone de navigation limitée.
  #   Plutôt que d'encombrer le navset principal avec les onglets de config,
  #   on les isole dans un modal accessible via un bouton engrenage flottant
  #   (bas droite). Le modal est reconstruit à chaque ouverture selon le rôle
  #   de l'utilisateur — il ne montre que les onglets auxquels il a accès.

  observeEvent(input_main_app$open_config_modal, {
    role <- main_session$userData$user_info$user_role()

    config_panels <- list(
      nav_panel(title = "Votre compte", value = "your_account", mod_config_ui1("config"))
    )
    if (role %in% c("admin", "super_admin", "dev")) {
      config_panels <- c(config_panels, list(
        nav_panel(title = "Administration", value = "admin_access", mod_config_ui2("config"))
      ))
    }
    if (role %in% c("super_admin", "dev")) {
      config_panels <- c(config_panels, list(
        nav_panel(title = "Super Admin", value = "super_admin_access", mod_config_ui3("config"))
      ))
    }
    if (role == "dev") {
      config_panels <- c(config_panels, list(
        nav_panel(title = "Dev", value = "dev_access", mod_config_ui4("config"))
      ))
    }

    showModal(modalDialog(
      title     = tagList(icon("gear"), " Configuration"),
      do.call(navset_tab, config_panels),
      size      = "l",
      easyClose = TRUE,
      footer    = modalButton("Fermer")
    ))
  })

}

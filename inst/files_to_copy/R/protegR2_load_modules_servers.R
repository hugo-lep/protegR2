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

}

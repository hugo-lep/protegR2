print("protegR2_load_modules_UIs — style: fluid")

# Ce fichier est copié dans R/ de ton projet par protegR2_init_layout("fluid").
# C'est ici que tu branches tes propres modules Shiny.
#
# Style "fluid" : conteneur pleine largeur (page_fluid) avec navigation par
# pills verticaux intégrés (navset_pill_list). C'est le layout le plus simple
# et le plus flexible — aucune mécanique de synchronisation côté serveur requise.
#
# Architecture :
#   navset_pill_list() gère navigation ET contenu dans un seul widget :
#     - pills verticaux affichés dans une colonne à gauche
#     - contenu du panel sélectionné affiché dans la zone droite
#   Contrairement au style "sidebar", tout est auto-contenu — pas besoin de
#   deux navsets séparés ni d'observateur de synchronisation.
#
# Variantes possibles :
#   Si tu préfères des onglets horizontaux, remplace navset_pill_list() par
#   navset_tab() ou navset_underline(). La convention id = "nav_tab" reste
#   obligatoire dans tous les cas pour que protegR2_server mette à jour l'URL.
#
# Convention obligatoire : id = "nav_tab" sur le navset_pill_list().

protegR2_load_modules_UIs <- function(session, tr) {

  selected <- isolate(getQueryString(session))$page
  role     <- session$userData$user_info$user_role()
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
  # Inclus directement dans le navset (pas de modal comme fixed/fillable).
  # Le menu "Configuration" apparaît en bas de la liste de pills, comme dans
  # le style "navbar". L'accès est restreint selon le rôle de l'utilisateur.

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

  # ── Rendu : page_fluid + navset_pill_list ─────────────────────────────────
  # page_fluid() : conteneur Bootstrap pleine largeur, s'adapte à toutes les
  #   tailles d'écran. Pas de largeur maximale fixe (contrairement à page_fixed).
  #
  # navset_pill_list() : navigation verticale auto-contenue.
  #   well = FALSE   : supprime le fond grisé autour des pills (aspect plus propre).
  #   widths = c(2, 10) : 2/12 colonnes pour les pills, 10/12 pour le contenu
  #     (grille Bootstrap 12 colonnes). Ajuste selon tes besoins :
  #     c(2, 10) → pills étroits   | c(3, 9) → pills plus larges.
  page_fluid(
    do.call(navset_pill_list, c(
      list(
        id      = "nav_tab",
        selected = selected,
        well    = FALSE,
        widths  = c(2, 10)
      ),
      panels
    ))
  )
}

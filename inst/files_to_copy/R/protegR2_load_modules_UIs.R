print("protegR2_load_modules_UIs")

# Ce fichier est copié dans R/ de ton projet à l'initialisation.
# C'est ici que tu branches tes propres modules Shiny.
#
# La fonction retourne une liste de nav_panel() et nav_menu() — des objets bslib.
# protegR2_ui() reçoit cette liste et l'affiche selon le style choisi
# ("sidebar", "navbar", "fluid", "fillable"). Tu n'as pas besoin de savoir
# quel style sera utilisé ici : tu construis juste la liste de panneaux.
#
# Logique de navigation :
#   nav_panel("Titre", ui)          → un panneau simple
#   nav_menu("Titre",               → un groupe avec sous-panneaux
#     nav_panel("Sous-titre", ui),
#     nav_panel("Sous-titre", ui)
#   )
#
# Logique conditionnelle par rôle :
#   Les panneaux sont ajoutés à la liste uniquement si la condition est vraie.
#   Les 4 rôles disponibles : "user", "admin", "super_admin", "dev"

protegR2_load_modules_UIs <- function(session, tr) {
  req(session$userData$user_info$user_role())

  role <- session$userData$user_info$user_role()

  # ── Panneaux principaux ──────────────────────────────────────────────────────
  # Visibles pour tous les rôles.
  # Remplace ces modules par les tiens selon ton projet.

  panels <- list(

    nav_panel(tr("menu1_sidebar_type_access"),
      icon = icon("house"),
      mod_demo2_ui("demo2", session = session)
    ),

    nav_panel(tr("menu2_module_demo"),
      icon = icon("chart-bar"),
      mod_demo1_ui("demo1", tr)
    ),

    # Exemple de nav_menu : un groupe avec deux sous-panneaux
    nav_menu(tr("subItem_test"),
      icon = icon("folder"),
      nav_panel(tr("subitem1"), mod_demo_subitem1_ui("subitem1")),
      nav_panel(tr("subitem2"), mod_demo_airplane_ui("turn_plane"))
    )

  )

  # ── Panneaux de configuration ────────────────────────────────────────────────
  # Conditionnels selon le rôle. Chaque niveau de rôle voit ses propres onglets
  # en plus de celui du niveau inférieur.

  # "your_account" : visible par tous les rôles
  config_panels <- list(
    nav_panel(tr("your_account"), mod_config_ui1("config"))
  )

  # "admin_access" : admin, super_admin, dev
  if (role %in% c("admin", "super_admin", "dev")) {
    config_panels <- c(config_panels, list(
      nav_panel(tr("admin_access"), mod_config_ui2("config"))
    ))
  }

  # "super_admin_access" : super_admin, dev
  if (role %in% c("super_admin", "dev")) {
    config_panels <- c(config_panels, list(
      nav_panel(tr("super_admin_access"), mod_config_ui3("config"))
    ))
  }

  # "dev_access" : dev uniquement
  if (role == "dev") {
    config_panels <- c(config_panels, list(
      nav_panel(tr("dev_access"), mod_config_ui4("config"))
    ))
  }

  # Regroupement des panneaux de config dans un nav_menu
  # do.call permet de passer une liste de longueur variable à nav_menu()
  panels <- c(panels, list(
    do.call(nav_menu, c(
      list(tr("configuration"), icon = icon("gear")),
      config_panels
    ))
  ))

  return(panels)
}

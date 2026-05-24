print("protegR2_load_modules_UIs — style: navbar")

# Ce fichier est copié dans R/ de ton projet par protegR2_init_layout("navbar").
# C'est ici que tu branches tes propres modules Shiny.
#
# Style "navbar" : barre de navigation horizontale en haut (page_navbar).
# La barre collapse automatiquement en icône hamburger sur mobile (Bootstrap natif).
#
# Logout + sélecteur de langue :
#   Ces deux éléments sont intégrés directement dans la navbar via nav_item(),
#   ce qui leur permet de s'intégrer naturellement au comportement hamburger.
#   Les versions "fixed" rendues par protegR2_ui() / protegR2_server() sont
#   masquées par le CSS ci-dessous (classes protegr2-logout-fixed et
#   protegr2-idioma-fixed ajoutées dans protegR2.R).
#
#   Note sur les IDs dupliqués :
#     logout       → même inputId que le bouton fixe — les deux déclenchent
#                    le même observeEvent côté serveur, sans conflit.
#     select_idioma → même inputId que le sélecteur fixe — celui-ci étant
#                    masqué (display:none), seul le nav_item est interactif.
#                    Shiny enregistre les deux mais l'utilisateur n'interagit
#                    qu'avec celui visible.
#
# Convention obligatoire : id = "nav_tab" sur le page_navbar().

protegR2_load_modules_UIs <- function(session, tr) {

  selected      <- isolate(getQueryString(session))$page %||% "home"
  role          <- session$userData$user_info$user_role()
  config_global <- session$userData$config_global
  req(role)

  # ── Backend ────────────────────────────────────────────────────────────────
  backend <- config_global$protegR2$user_config_backend %||% "none"

  # ── CSS masquant les boutons fixes + pas d'engrenage flottant ────────────
  # gear = FALSE : la configuration est dans le nav_menu() ci-dessous,
  # pas besoin du bouton flottant.
  layout_controls <- protegr2_layout_controls(gear = FALSE)

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

  # ── Panneaux de configuration (selon le rôle et le backend) ───────────────
  # Masqués en mode local : les mots de passe sont définis dans
  # protegR2_local_users.R — l'interface de gestion ne ferait rien d'utile et
  # donnerait une fausse impression que les changements sont persistés.
  #
  # En mode s3 / postgres : tous les utilisateurs voient "Votre compte",
  # les rôles élevés voient les panneaux supplémentaires selon leur niveau.

  config_panels <- if (backend == "local") {
    NULL
  } else {
    panels_cfg <- list(
      nav_panel(title = tr("your_account"), value = "your_account", mod_config_ui1("config"))
    )
    if (role %in% c("admin", "super_admin", "dev")) {
      panels_cfg <- c(panels_cfg, list(
        nav_panel(title = tr("admin_access"), value = "admin_access", mod_config_ui2("config"))
      ))
    }
    if (role %in% c("super_admin", "dev")) {
      panels_cfg <- c(panels_cfg, list(
        nav_panel(title = tr("super_admin_access"), value = "super_admin_access", mod_config_ui3("config"))
      ))
    }
    if (role == "dev") {
      panels_cfg <- c(panels_cfg, list(
        nav_panel(title = tr("dev_access"), value = "dev_access", mod_config_ui4("config"))
      ))
    }
    panels_cfg
  }

  # Le nav_menu "Configuration" n'est ajouté que si config_panels existe.
  # En mode local config_panels est NULL → aucun menu de configuration affiché.
  if (!is.null(config_panels)) {
    panels <- c(panels, list(
      do.call(nav_menu, c(
        list(title = tr("configuration"), icon = icon("gear")),
        config_panels
      ))
    ))
  }

  # ── Éléments droite de la navbar ──────────────────────────────────────────
  # nav_spacer() pousse tout ce qui suit vers la droite.
  # nav_item()   insère du HTML arbitraire dans la navbar.
  # Ces éléments s'intègrent au hamburger automatiquement sur mobile.

  # ── Dropdown de sélection de langue ──────────────────────────────────────
  # protegr2_lang_dropdown() retourne le tags$div Bootstrap, ou NULL si
  # show_idioma est FALSE. Dans la navbar, il faut l'envelopper dans nav_item()
  # pour qu'il s'intègre à la barre et au hamburger mobile — c'est la seule
  # différence avec fluid/sidebar qui utilisent le résultat directement.
  lang_dropdown <- {
    dd <- protegr2_lang_dropdown(config_global, session$userData$idioma())
    if (!is.null(dd)) nav_item(dd)
  }

  right_items <- list(
    nav_spacer(),
    lang_dropdown,

    # ── Bouton logout ─────────────────────────────────────────────────────
    nav_item(
      actionButton(
        inputId = "logout",
        label   = tagList(icon("right-from-bracket"), " ", tr("logout")),
        class   = "btn btn-outline-secondary btn-sm"
      )
    )
  )

  # ── Rendu : page_navbar ────────────────────────────────────────────────────
  # do.call() permet de passer une liste de longueur variable à page_navbar().
  # title       : texte à gauche de la barre — lu depuis config_global.
  # id          : obligatoire pour la restauration d'onglet via l'URL.
  # collapsible : TRUE = hamburger sur mobile (comportement Bootstrap natif).
  # underline   : TRUE = soulignement de l'onglet actif.
  tagList(
    layout_controls,
    do.call(page_navbar, c(
      list(
        title       = config_global$header_title %||% "Application",
        id          = "nav_tab",
        selected    = selected,
        underline   = TRUE,
        collapsible = TRUE
      ),
      panels,
      right_items
    ))
  )
}

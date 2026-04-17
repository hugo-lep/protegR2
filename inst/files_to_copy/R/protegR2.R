print("protegR2_ui")

# ══════════════════════════════════════════════════════════════════════════════
# protegR2_ui()
# ══════════════════════════════════════════════════════════════════════════════
#
# Rôle : construire la coquille statique de l'application.
# "Statique" signifie qu'elle est évaluée une seule fois au démarrage du serveur,
# avant même qu'un utilisateur se connecte. Elle ne change plus après.
#
# Tout ce qui dépend de l'état de connexion (login / app) est rendu
# dynamiquement côté serveur via uiOutput("main_ui").
#
# Paramètres :
#   config_global — liste chargée depuis S3, contient les paramètres de l'app
#   style         — layout de l'application une fois connecté :
#                     "sidebar"  → navigation verticale à gauche (navset_pill_list)
#                     "navbar"   → onglets horizontaux en haut (navset_tab)
#                     "fluid"    → page libre avec onglets (navset_tab dans page_fluid)
#                     "fillable" → plein écran (navset_card_underline)
#   idioma        — TRUE pour afficher le sélecteur de langue, FALSE pour le cacher

protegR2_ui <- function(config_global, style = "sidebar", idioma = TRUE) {

  # ── Thème bslib (Bootstrap 5) ───────────────────────────────────────────────
  # bs_theme() centralise l'apparence de toute l'application.
  # bootswatch : thème prédéfini (voir https://bootswatch.com pour les options)
  # primary    : couleur principale (boutons, liens actifs, etc.)
  # Les valeurs viennent de config_global si elles sont définies,
  # sinon on utilise les valeurs par défaut avec %||% (opérateur "ou si NULL").
  theme <- bs_theme(
    bootswatch = config_global$bootswatch %||% "flatly",
    primary    = config_global$primary_color %||% "#3c8dbc"
  )

  # ── Google Analytics (optionnel) ─────────────────────────────────────────────
  # Si config_global$ga_id est défini (ex. "G-XXXXXXXXXX"), on injecte
  # automatiquement le script GA4 dans le <head>. Sinon, ga_script vaut NULL
  # et Shiny ignore simplement un élément NULL dans la UI.
  ga_script <- if (!is.null(config_global$ga_id)) {
    tagList(
      # Chargement asynchrone du script GA — "async = NA" produit <script async>
      tags$script(
        async = NA,
        src   = paste0("https://www.googletagmanager.com/gtag/js?id=", config_global$ga_id)
      ),
      tags$script(HTML(paste0(
        "window.dataLayer = window.dataLayer || [];
         function gtag(){dataLayer.push(arguments);}
         gtag('js', new Date());
         gtag('config', '", config_global$ga_id, "');"
      )))
    )
  } else {
    NULL
  }

  # ── Structure de la page ─────────────────────────────────────────────────────
  # add_cookie_handlers() est fourni par le package {cookies}. Il enveloppe
  # la UI pour intercepter les cookies du navigateur et les rendre accessibles
  # côté serveur via input$cookies. Indispensable pour l'auto-login.
  #
  # page_fluid() est choisi comme conteneur universel parce que :
  #   1. Il est compatible avec tous les composants bslib (navset_*, sidebar, etc.)
  #   2. Il n'impose aucune structure — le serveur décide du layout via uiOutput()
  #   3. La page de login et la page app peuvent avoir des layouts completement différents
  #      sans conflit CSS (problème qui existait avec shinydashboard)

  add_cookie_handlers(
    page_fluid(
      theme = theme,

      # useShinyjs() active les fonctions JavaScript de {shinyjs}
      # (toggle, hide, show, etc.) utilisées dans l'application.
      # Doit être appelé une fois dans la UI, de préférence au début du body.
      useShinyjs(),

      tags$head(

        # Injection des scripts Google Analytics si configurés
        ga_script,

        # ── Handler de déconnexion forcée ────────────────────────────────────
        # Ce handler JavaScript est déclenché depuis le serveur avec :
        #   session$sendCustomMessage("forceDisconnect", list(message = "..."))
        # Il affiche un message à l'utilisateur puis recharge la page,
        # ce qui le renvoie à la page de login.
        # Utilisé quand une session simultanée est détectée (autre appareil).
        tags$script(HTML("
          Shiny.addCustomMessageHandler('forceDisconnect', function(msg) {
            alert(msg.message);
            location.reload();
          });
        "))

      ),

      # ── Sélecteur de langue (optionnel) ──────────────────────────────────────
      # Affiché uniquement si idioma = TRUE dans ui.R.
      # position: fixed le maintient visible en haut à droite même en scrollant.
      # z-index élevé pour qu'il passe au-dessus de tous les autres éléments.
      if (idioma) {
        div(
          style = "position: fixed; top: 10px; right: 15px; z-index: 9999; width: 110px;",
          selectInput(
            inputId  = "select_idioma",
            label    = NULL,
            choices  = c("Français" = "fr", "English" = "en", "Español" = "es"),
            selected = config_global$idioma %||% "fr",
            width    = "110px"
          )
        )
      },

      # ── Zone principale ───────────────────────────────────────────────────────
      # Toute la logique d'affichage (login vs app) est gérée par le serveur.
      # Le serveur remplace ce placeholder par la page de login ou l'application
      # selon l'état de connexion de l'utilisateur.
      uiOutput("main_ui")

    )
  )
}


print("protegR2_server")

# ══════════════════════════════════════════════════════════════════════════════
# protegR2_server()
# ══════════════════════════════════════════════════════════════════════════════
# À réécrire en Phase 2.3 — conservé temporairement pour ne pas casser l'app

protegR2_server <- function(input, output, session, style = "sidebar") {
  ns <- session$ns

  # ── Initialisation de session ─────────────────────────────────────────────
  # session$userData est un environnement R associé à chaque session utilisateur.
  # Il persiste pendant toute la durée de la session et est accessible partout
  # dans le serveur. C'est ici qu'on stocke les informations de l'utilisateur connecté.
  session$userData$config_s3_location <- config_s3_location
  session$userData$config_global      <- config_global
  session$userData$style              <- style   # style transmis à tous les renderUI
  session$userData$timestamp_cookie_check <- reactiveVal(Sys.time())
  session$userData$timestamp_cookie_reset <- reactiveVal(Sys.time())
  session$userData$idioma <- reactiveVal(config_global$idioma %||% "fr")

  # user_info regroupe toutes les informations réactives sur l'utilisateur connecté.
  # reactiveVal(NULL) = valeur réactive initialisée à NULL (= personne connecté).
  # token_value n'est pas réactif car il ne déclenche pas de re-rendu UI.
  session$userData$user_info <- list(
    valid_user  = reactiveVal(NULL),  # données complètes de l'utilisateur (data.frame row)
    token_value = NULL,               # UUID de la session courante (non réactif)
    user_auth   = reactiveVal(NULL),  # username si connecté, NULL sinon — contrôle l'affichage
    user_role   = reactiveVal(NULL)   # rôle : "user", "admin", "super_admin", "dev"
  )

  # tr() est la fonction de traduction. Elle prend une clé (ex. "login") et
  # retourne le texte dans la langue active (session$userData$idioma).
  # make_tr() est défini dans i18n_db.R et utilise le reactiveVal idioma
  # pour retourner automatiquement la bonne traduction quand la langue change.
  tr <- make_tr(i18n = i18n_db, lang = session$userData$idioma)

  # just_logged_out empêche le bloc d'auto-login de se déclencher immédiatement
  # après un logout volontaire. Sans ça, le cookie encore présent dans le navigateur
  # reconnecterait l'utilisateur à la seconde même où il clique "Déconnexion".
  just_logged_out <- reactiveVal(FALSE)

  # Chargement des modules serveur du projet (défini dans protegR2_load_modules_servers.R)
  protegR2_load_modules_servers(sessions, input, session)

  # ── Changement de langue ────────────────────────────────────────────────────
  # observeEvent() s'exécute uniquement quand input$select_idioma change.
  # Il met à jour session$userData$idioma, ce qui déclenche automatiquement
  # la mise à jour de tous les textes traduits via tr().
  observeEvent(input$select_idioma, {
    session$userData$idioma(input$select_idioma)
  })

  # ── Récupération de l'IP client ─────────────────────────────────────────────
  # observe() sans déclencheur explicite s'exécute une fois au démarrage
  # puis à chaque fois que ses dépendances réactives changent.
  # req() arrête silencieusement l'exécution si url_hostname n'est pas encore
  # disponible (évite une erreur au tout début du chargement).
  observe({
    req(session$clientData$url_hostname)
    fetch_client_ip(session)
  })

  # ── Section login / logout / auto-login — À réécrire en Phase 2.3 ──────────
  # Conservé temporairement pour maintenir le fonctionnement de base.

  observeEvent(input$login, {
    just_logged_out(FALSE)
    users_info    <- s3readRDS_HL(object = "config_files/users_auth.rds")
    valid_user_df <- users_info %>% filter(username == input$username)

    if (nrow(valid_user_df) != 1) {
      sendSweetAlert(session, "Oops!", tr("invalid_username"), "error")
      return(NULL)
    }

    valid_user <- as.list(valid_user_df)

    if (!valid_user$active) {
      sendSweetAlert(session, "Oops!", tr("inactive_account"), "error")
      return(NULL)
    }

    if (!is.na(valid_user$expire_date) && valid_user$expire_date < Sys.Date()) {
      sendSweetAlert(session, "Oops!", tr("expired_account"), "error")
      return(NULL)
    }

    if (!password_verify(valid_user$hash_password, input$password)) {
      sendSweetAlert(session, "Oops!", tr("invalid_credentials"), "error")
      return(NULL)
    }

    token_value <- UUIDgenerate(use.time = FALSE)
    session$user <- input$username
    sessions[[session$token]] <- list(session = session, valid_user_df = valid_user_df)

    cookie_validator_delete(input$username, session)
    perform_login(valid_user, token_value, input, session)
  })

  observeEvent(input$logout, {
    just_logged_out(TRUE)
    perform_logout(session = session)
  })

  observe({
    if (!just_logged_out() && is.null(session$userData$user_info$user_auth())) {
      S3_save_cookie_valid <- cookie_auto_login(input = input, session = session)

      if (!is.null(S3_save_cookie_valid)) {
        valid_user_df <- s3readRDS_HL(object = "config_files/users_auth.rds") %>%
          filter(username == S3_save_cookie_valid[[1, "username"]])
        valid_user        <- as.list(valid_user_df)
        session$user      <- valid_user$username
        sessions[[session$token]] <- list(session = session, valid_user_df = valid_user_df)

        perform_login(
          valid_user  = valid_user,
          token_value = S3_save_cookie_valid[[1, "token_value"]],
          input       = input,
          session     = session
        )
      }
    }
  })

  # ── Rendu principal : login ou application ──────────────────────────────────
  # C'est le cœur de la bascule login/app.
  # user_auth() vaut NULL = personne connecté → page de login
  # user_auth() vaut un username = connecté → application avec le layout choisi
  #
  # reactive() crée un objet réactif réutilisable. On l'appelle my_panels()
  # pour récupérer la liste de nav_panel() selon le rôle de l'utilisateur.
  # req() garantit que user_role() est disponible avant de construire les panels.
  my_panels <- reactive({
    req(session$userData$user_info$user_role())
    protegR2_load_modules_UIs(session, tr)
  })

  output$main_ui <- renderUI({

    if (is.null(session$userData$user_info$user_auth())) {

      # ── Page de login ───────────────────────────────────────────────────────
      # Rendue dans un div plein écran sans aucun élément de navigation.
      # tr est passé pour traduire les libellés si idioma = TRUE.
      protegR2_login_ui(config_global, tr = tr)

    } else {

      # ── Application connectée ───────────────────────────────────────────────
      # Le bouton logout est affiché en position fixe en haut à droite,
      # visible peu importe le layout ou la page active.
      tagList(

        div(
          style = "position: fixed; top: 10px; right: 140px; z-index: 9998;",
          actionButton("logout",
                       label = tagList(icon("right-from-bracket"), tr("logout")),
                       class = "btn-outline-secondary btn-sm")
        ),

        # Dispatch du layout selon le style choisi.
        # do.call() permet de passer une liste de longueur variable (my_panels())
        # comme arguments individuels à la fonction de layout.
        # L'id "nav_tab" permet au serveur de lire/modifier l'onglet actif
        # via input$nav_tab et nav_select().
        switch(style,

          "sidebar" = do.call(
            navset_pill_list,
            c(list(id = "nav_tab", well = FALSE), my_panels())
          ),

          "navbar" = do.call(
            navset_underline,
            c(list(id = "nav_tab"), my_panels())
          ),

          "fluid" = do.call(
            navset_tab,
            c(list(id = "nav_tab"), my_panels())
          ),

          "fillable" = do.call(
            navset_card_underline,
            c(list(id = "nav_tab"), my_panels())
          )
        )
      )
    }
  })

  # ── Vérification d'activité (cookie refresh) ────────────────────────────────
  # throttle() limite la fréquence de déclenchement : même si l'utilisateur
  # clique 100 fois par minute, ce bloc ne s'exécute qu'une fois toutes les 4 min.
  # C'est important car chaque déclenchement fait un appel S3.
  throttled_inputs <- reactive(reactiveValuesToList(input)) %>% throttle(240000)

  observeEvent(throttled_inputs(), {
    req(session$userData$user_info$user_auth())
    print("start cookie refresh")

    now         <- Sys.time()
    token_value <- session$userData$user_info$token_value
    file_path   <- paste0("session/", token_value, ".rds")

    if (!s3exist_HL(object = file_path) ||
        s3readRDS_HL(object = file_path) %>% pull(expiration) < now) {
      print("cookie validator n'existe pas ou est expiré — déconnexion")
      just_logged_out(TRUE)
      session$userData$user_info$user_auth(NULL)
    } else {
      print("cookie validator valide — refresh du cookie")
      cookie_set_user(input, session)
      session$userData$timestamp_cookie_reset(now)
    }
  })

  # ── Vérification rapide d'inactivité toutes les 45 secondes ─────────────────
  # invalidateLater(45000) force Shiny à ré-exécuter ce bloc toutes les 45s.
  # Si le cookie navigateur a disparu (inactivité, fermeture d'onglet, etc.),
  # on déconnecte l'utilisateur proprement.
  observe({
    req(session$userData$user_info$user_auth())
    invalidateLater(45000)

    print("vérification cookie d'activité")

    if (is.null(get_cookie(config_global$cookie_name))) {
      print("cookie absent — déconnexion automatique")
      just_logged_out(TRUE)
      perform_logout(session = session)
    }
  })

  # ── Nettoyage à la fermeture de session ─────────────────────────────────────
  # onSessionEnded() s'exécute quand l'utilisateur ferme l'onglet ou le navigateur
  # sans cliquer sur "Déconnexion". On nettoie l'entrée dans l'objet global sessions.
  session$onSessionEnded(function() {
    if (!is.null(session$user)) {
      rm(list = session$token, envir = sessions)
    }
  })
}

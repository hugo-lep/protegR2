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

#' Interface utilisateur principale de protegR2
#'
#' Construit la coquille statique de l'application Shiny. Tout ce qui
#' depend de l'etat de connexion est rendu dynamiquement via
#' \code{uiOutput("main_ui")}.
#'
#' @param config_global Liste de configuration chargee depuis S3
#' @param style Layout : \code{"sidebar"}, \code{"navbar"}, \code{"fluid"}
#'   ou \code{"fillable"}
#' @param idioma \code{TRUE} pour afficher le selecteur de langue
#'
#' @importFrom bslib bs_theme page_fluid
#' @importFrom shiny uiOutput tags div selectInput HTML bootstrapLib
#' @importFrom shinyjs useShinyjs
#' @importFrom cookies add_cookie_handlers
#' @importFrom rlang %||%
#'
#' @export
protegR2_ui <- function(config_global, style = "sidebar", idioma = TRUE) {

  # ── Thème bslib (Bootstrap 5) ───────────────────────────────────────────────
  # bs_theme() centralise l'apparence de toute l'application.
  # bootswatch : thème prédéfini (voir https://bootswatch.com pour les options)
  # primary    : couleur principale (boutons, liens actifs, etc.)
  # Les valeurs viennent de config_global si elles sont définies,
  # sinon on utilise les valeurs par défaut avec %||% (opérateur "ou si NULL").
  theme <- bs_theme(
    bootswatch = config_global$protegR2$theme$bootswatch %||% "darkly",
    primary    = config_global$protegR2$theme$primary    %||% "#3c8dbc"
  )

  # ── Google Analytics (optionnel) ─────────────────────────────────────────────
  # Si config_global$protegR2$ga_id est défini (ex. "G-XXXXXXXXXX"), on injecte
  # automatiquement le script GA4 dans le <head>. Sinon, ga_script vaut NULL
  # et Shiny ignore simplement un élément NULL dans la UI.
  ga_script <- if (!is.null(config_global$protegR2$ga_id)) {
    tagList(
      # Chargement asynchrone du script GA — "async = NA" produit <script async>
      tags$script(
        async = NA,
        src   = paste0("https://www.googletagmanager.com/gtag/js?id=", config_global$protegR2$ga_id)
      ),
      tags$script(HTML(paste0(
        "window.dataLayer = window.dataLayer || [];
         function gtag(){dataLayer.push(arguments);}
         gtag('js', new Date());
         gtag('config', '", config_global$protegR2$ga_id, "');"
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
  # tagList() remplace l'ancien page_fluid() comme conteneur externe.
  # Pourquoi ce changement :
  #   page_fluid() imposait un div.container-fluid autour du uiOutput("main_ui"),
  #   ce qui créait un page_* imbriqué dans un autre page_* quand le template
  #   retournait page_sidebar(), page_fillable(), etc. — layout cassé pour
  #   les styles plein écran (fillable notamment).
  #
  # tagList() est un conteneur neutre — il n'ajoute aucun div dans le DOM.
  # Le theme (bs_theme) est une dépendance HTML : bslib l'injecte directement
  # dans <head> qu'il soit dans un page_* ou un tagList(). Les templates
  # gardent donc leur propre page_* au niveau racine, sans wrapper parasite.
  #
  # Les autres éléments d'infrastructure (useShinyjs, tags$head, sélecteur
  # de langue) restent ici — ils n'ont pas leur place dans les templates.

  add_cookie_handlers(
    tagList(
      # bootstrapLib() convertit le bs_theme en dépendances HTML (CSS/JS)
      # injectables dans <head> sans imposer de structure de page.
      # C'est ce que page_fluid(theme=) fait en interne — on l'appelle
      # directement ici pour éviter le div.container-fluid qu'il ajouterait.
      bootstrapLib(theme),
      useShinyjs(),   # active les fonctions JS (toggle, hide, show) — doit être appelé 1x dans ui

      tags$head(

        ga_script, # Injection des scripts Google Analytics si configurés, ignoré si NULL

        # ── Handler de déconnexion forcée ────────────────────────────────────
        # Ce handler JavaScript est déclenché depuis le serveur avec :
        #   session$sendCustomMessage("forceDisconnect", list(message = "..."))
        # Il affiche un message à l'utilisateur puis recharge la page,
        # ce qui le renvoie à la page de login.
        # Utilisé quand une session simultanée est détectée (autre appareil).
        tags$script(HTML("
          Shiny.addCustomMessageHandler('forceDisconnect', function(msg) {
            // SweetAlert2 est charge automatiquement par shinyWidgets.
            // On l'utilise ici pour un popup coherent avec le reste de l'app.
            // Fallback vers alert() natif si Swal n'est pas disponible
            // (environnement de test sans shinyWidgets, etc.).
            // allowOutsideClick: false oblige l'utilisateur a cliquer OK
            // avant que la page se recharge -- evite de rester bloque
            // sur une session zombie.
            if (typeof Swal !== 'undefined') {
              Swal.fire({
                title: 'Session terminee',
                text: msg.message,
                icon: 'warning',
                allowOutsideClick: false,
                confirmButtonText: 'OK'
              }).then(function() {
                location.reload();
              });
            } else {
              alert(msg.message);
              location.reload();
            }
          });
        "))

      ),

      # ── Sélecteur de langue (optionnel) ──────────────────────────────────────
      # Affiché uniquement si config_global$protegR2$lang_choice est TRUE (défaut : TRUE).
      # Visible sur la page de login ET dans l'app — les templates masquent
      # la version fixe (.protegr2-idioma-fixed) et proposent leur propre
      # dropdown intégré à leur layout quand show_idioma est TRUE.
      if (config_global$protegR2$lang_choice %||% TRUE) {
        # Construire les choices depuis lang_options (liste nommée code → list(mini_label, label))
        # Si lang_options est absent (config non migrée), fallback vers les 3 langues par défaut.
        lang_opts <- config_global$protegR2$lang_options %||% list(
          fr = list(mini_label = "FR", label = "Français"),
          en = list(mini_label = "EN", label = "English"),
          es = list(mini_label = "ES", label = "Español")
        )
        lang_choices <- stats::setNames(names(lang_opts),
                                        sapply(lang_opts, `[[`, "label"))
        div(
          class = "protegr2-idioma-fixed",
          style = "position: fixed; top: 10px; right: 15px; z-index: 9999; width: 110px;",
          selectInput(
            inputId  = "select_idioma",
            label    = NULL,
            choices  = lang_choices,
            selected = config_global$protegR2$lang_default %||% "fr",
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
utils::globalVariables(c(
  "config_s3_location_path","config_global",
  "protegR2_load_modules_servers","protegR2_load_modules_UIs","protegR2_login_ui"
))
# ══════════════════════════════════════════════════════════════════════════════
# protegR2_server()
# ══════════════════════════════════════════════════════════════════════════════
#
# Rôle : orchestrer toute la logique serveur de l'application.
#
# Cette fonction est le "chef d'orchestre" : elle initialise la session,
# gère l'authentification (login manuel, auto-login, logout), protège contre
# les attaques brute force, maintient le cookie de session actif, et dispatche
# l'interface entre la page de login et l'application selon l'état de connexion.
#
# Paramètre :
#   style — identique à celui de protegR2_ui() — "sidebar", "navbar", "fluid",
#           "fillable". Doit être le même dans ui.R et server.R (défini une seule
#           fois dans global.R, puis transmis aux deux fonctions).

#' Serveur principal de protegR2
#'
#' Orchestre toute la logique serveur : initialisation de session,
#' login manuel, auto-login par cookie, logout, protection brute force,
#' refresh de session et dispatch du layout.
#'
#' @param input,output,session Parametres standards d'une fonction serveur Shiny
#' @param style Layout : \code{"sidebar"}, \code{"navbar"}, \code{"fluid"}
#'   ou \code{"fillable"}
#' @param pool Pool de connexion postgres (via \code{pool::dbPool()}). Requis
#'   si \code{user_config_backend = "postgres"} dans \code{config_global},
#'   \code{NULL} sinon.
#'
#' @importFrom bslib navset_pill_list navset_underline navset_tab navset_card_underline page_navbar page_fixed page_fillable
#' @importFrom shiny observe observeEvent reactive renderUI req reactiveVal
#'   invalidateLater reactiveValuesToList throttle actionButton icon tagList
#'   isolate updateQueryString getQueryString
#' @importFrom shinyWidgets sendSweetAlert
#' @importFrom dplyr filter pull
#' @importFrom magrittr %>%
#' @importFrom uuid UUIDgenerate
#' @importFrom sodium password_verify
#' @importFrom s3db s3readRDS_HL s3exist_HL
#' @importFrom utilsHL make_tr
#' @importFrom DBI dbGetQuery
#' @importFrom rlang %||%
#'
#' @export
protegR2_server <- function(input, output, session, style = "sidebar", pool = NULL) {

  # ── Fonction helper locale : incrément du compteur de brute force ──────────
  #
  # Règle de verrouillage :
  #   Tentatives 1 … (max_login_attempts - 1) : compteur incrémenté, pas de verrou
  #   Tentative max_login_attempts+            : verrou de lockout_duration_s secondes
  #
  # Les seuils sont lus depuis config_global$protegR2$security (défini dans
  # global.R et copié dans session$userData au démarrage). Les valeurs %||%
  # servent de fallback si la clé est absente d'une config ancienne.
  #
  # Note : increment_failures est une closure — elle capture `session` par
  # référence. session$userData$config_global est évalué à l'appel (pas à la
  # définition), donc les valeurs sont toujours fraîches et correctes.
  #
  # Le verrou est local à la session — il disparaît si l'utilisateur ferme
  # et rouvre l'onglet. Un verrou persistant sur S3 est prévu en Phase 2.7.
  increment_failures <- function(failures) {
    security     <- session$userData$config_global$protegR2$security
    max_attempts <- security$max_login_attempts %||% 5
    lockout_s    <- security$lockout_duration_s %||% 30

    new_count    <- failures$count + 1
    locked_until <- if (new_count >= max_attempts) Sys.time() + lockout_s else NULL
    list(count = new_count, locked_until = locked_until)
  }

  # ── Fonction helper locale : vérification d'accès au host restreint ─────────
  #
  # Certains hosts (ex. URLs de staging ou de dev) nécessitent que l'utilisateur
  # ait dev_access = TRUE dans son profil. Le rôle "dev" passe toujours.
  #
  # La liste des hosts restreints vient de config_global$protegR2$security$restricted_hosts.
  # Si NULL ou vide, l'accès est libre (comportement par défaut, aucun host restreint).
  #
  # En développement local, override_host permet de simuler un host restreint sans
  # déployer — il se décommente dans global.R du projet (jamais ici ni sur S3).
  #
  # Retourne TRUE si l'accès est accordé.
  # Retourne FALSE et affiche une alerte si l'accès est refusé.
  # Dans les deux cas, la session reste à l'état pré-login — c'est l'appelant
  # qui décide de continuer ou de return(NULL).
  check_host_access <- function(valid_user) {

    restricted <- config_global$protegR2$security$restricted_hosts

    # Aucun host restreint configuré → accès libre pour tous
    if (is.null(restricted) || length(restricted) == 0) return(TRUE)

    # Identifiant de l'URL courante : hostname + pathname.
    # On combine les deux pour supporter les deux patterns de déploiement :
    #   - sous-domaine : "voyages-dev.avnumbers.ca/"   (pathname = "/")
    #   - sous-dossier : "avnumbers.ca/financedev/"    (pathname = "/financedev/")
    # override_host permet de simuler n'importe quelle valeur en local (127.0.0.1).
    current_host <- config_global$protegR2$security$override_host %||%
                    paste0(session$clientData$url_hostname,
                           session$clientData$url_pathname)

    # URL non restreinte → accès libre
    if (!current_host %in% restricted) return(TRUE)

    # Host restreint : "dev" passe toujours (implicite), les autres ont besoin du flag
    # isTRUE() gère proprement le cas où la colonne dev_access est absente du .rds
    # (utilisateurs créés avant l'ajout de la colonne) — NULL et NA deviennent FALSE.
    if (valid_user$role == "dev" || isTRUE(valid_user$dev_access)) return(TRUE)

    # Accès refusé — on affiche un message clair et on arrête ici
    sendSweetAlert(
      session,
      title = tr("access_denied")       %||% "Accès refusé",
      text  = tr("dev_access_required") %||%
              paste0("Votre compte n'est pas autorisé à accéder",
                     " à cette version de l'application."),
      type  = "error"
    )
    FALSE
  }

  # ── Initialisation de session ──────────────────────────────────────────────
  #
  # session$userData est un environnement R vide créé automatiquement par Shiny
  # pour chaque connexion utilisateur. Il est :
  #   - Isolé par session : chaque utilisateur a le sien
  #   - Persistant pendant toute la durée de la session (pas réinitialisé)
  #   - Accessible depuis n'importe quel module via session$userData (si la
  #     session principale est passée en paramètre, ce que font les modules
  #     de config de protegR2)
  #
  # On l'utilise comme "état global de session" — alternative propre aux
  # variables globales qui seraient partagées entre toutes les sessions.

  # get0() retourne NULL si config_s3_location n'existe pas dans l'environnement
  # global — c'est le cas en mode local (pas de connexion S3 requise).
  # En mode s3/postgres, la variable est définie dans global.R via
  # set_config_s3_location() / s3_connection_HL() et est lue normalement.
  session$userData$config_s3_location     <- get0("config_s3_location")
  session$userData$config_global          <- config_global
  session$userData$style                  <- style
  session$userData$pool                   <- pool   # NULL si backend != "postgres"
  session$userData$timestamp_cookie_check <- reactiveVal(Sys.time())
  session$userData$timestamp_cookie_reset <- reactiveVal(Sys.time())

  session$userData$idioma <- reactiveVal(config_global$protegR2$lang_default %||% "fr")

  # user_info est la liste centrale d'état de l'utilisateur connecté.

  session$userData$user_info <- list(
    valid_user  = reactiveVal(NULL),  # liste complète des données de l'utilisateur
    token_value = NULL,               # UUID de session (non réactif intentionnellement)
    user_auth   = reactiveVal(NULL),  # NULL = non connecté | username = connecté
    user_role   = reactiveVal(NULL)   # "user" | "admin" | "super_admin" | "dev"
  )

  # tr() est la fonction de traduction retournée par make_tr().
  # make_tr() crée une closure (une fonction qui "capture" ses paramètres) :
  # elle lit le reactiveVal idioma à chaque appel, donc tr("login") retourne
  # automatiquement la bonne langue sans qu'on ait besoin de la reconfigurer.
  #
  # project_var("i18n_db") remonte sys.frames() pour trouver la variable i18n_db
  # définie dans R/i18n_db.R du projet utilisateur — inaccessible directement
  # depuis le namespace du package installé. L'évaluation est forcée ici, dans
  # le contexte non-réactif du démarrage, évitant l'évaluation paresseuse qui
  # échouerait plus tard depuis un renderUI() ou un reactive().
  tr <- make_tr(i18n = project_var("i18n_db"), lang = session$userData$idioma)

  # ── Compteur d'échecs de connexion (protection brute force) ───────────────
  #
  # Stocké comme reactiveVal local (dans la portée de protegR2_server, pas dans
  # session$userData) car il n'est utilisé que dans ce fichier.
  #
  # Structure de la liste stockée :
  #   list(
  #     count        = 3,                    ← nombre de tentatives échouées
  #     locked_until = 2024-01-15 14:32:00   ← NULL ou horodatage de fin de verrou
  #   )
  #
  # Pourquoi un reactiveVal et pas une variable normale ?
  # Le bloc observeEvent(input$login, ...) doit lire et écrire cet état.
  # Avec une variable normale (count <- 0), la valeur serait réinitialisée
  # à chaque exécution du bloc. reactiveVal() persiste entre les exécutions.
  login_failures <- reactiveVal(list(count = 0, locked_until = NULL))

  # ── Flag anti-reconnexion immédiate après logout ───────────────────────────
  #
  # Problème sans ce flag :
  #   1. L'utilisateur clique "Déconnexion"
  #   2. perform_logout() met user_auth(NULL)
  #   3. L'observe() d'auto-login détecte que user_auth() est NULL
  #   4. Il trouve le cookie encore présent dans le navigateur (suppression async)
  #   5. Il reconnecte l'utilisateur → la déconnexion ne fonctionne pas !
  #
  # Solution : just_logged_out(TRUE) au moment du logout bloque l'auto-login.
  # Il repasse à FALSE au prochain clic sur "Connexion" (login manuel).
  just_logged_out <- reactiveVal(FALSE)

  # ── Capture des fonctions du projet utilisateur ───────────────────────────
  #
  # Les trois fonctions (login_ui, load_modules_UIs, load_modules_servers) sont
  # définies dans R/ du projet et sourcées par Shiny dans un environnement enfant
  # de globalenv() — inaccessible directement depuis un namespace de package.
  #
  # project_fn() remonte la pile d'appels (sys.frames()) pour les trouver.
  # Cela fonctionne uniquement dans un contexte NON-réactif (au démarrage).
  # À l'intérieur d'un renderUI() ou reactive(), la pile d'appels Shiny est
  # différente et sys.frames() ne voit plus la closure de server().
  #
  # Solution : capturer les trois références de fonctions ICI (au démarrage,
  # contexte non-réactif), les stocker dans des variables locales, et les
  # réutiliser partout — y compris dans les contextes réactifs.
  .login_ui        <- project_fn("protegR2_login_ui")
  .load_modules_UIs <- project_fn("protegR2_load_modules_UIs")

  # ── Chargement des modules serveur ────────────────────────────────────────
  # Défini dans protegR2_load_modules_servers.R (copié dans R/ du projet).
  # C'est ici qu'on démarre tous les modules Shiny du projet.
  # Les modules serveur doivent être appelés une fois, au démarrage de la session,
  # même si l'utilisateur n'est pas encore connecté — Shiny les met en attente.
  project_fn("protegR2_load_modules_servers")(sessions, input, session)

  # ── Changement de langue ──────────────────────────────────────────────────
  #
  # Ici on veut exactement observeEvent : réagir seulement quand l'utilisateur
  # change la langue, pas forcer une "non-traduction" au démarrage.
  observeEvent(input$select_idioma, {
    session$userData$idioma(input$select_idioma)
  })

  # ── Récupération de l'IP client ───────────────────────────────────────────
  #
  # observe() sans input explicite — ses dépendances sont implicites :
  # Shiny les détecte automatiquement à la première exécution.
  # Ici : session$clientData$url_hostname est la dépendance implicite.
  #
  # req(valeur) est une "garde réactive" :
  #   - Si valeur est NULL, NA, FALSE, ou vide → arrêt SILENCIEUX du bloc
  #   - Shiny ne lève pas d'erreur, il met juste le bloc en attente
  #   - Le bloc sera ré-exécuté dès que la dépendance devient disponible
  #
  # Sans req() ici : fetch_client_ip() serait appelée avec url_hostname = NULL
  # pendant les premières millisecondes de chargement → erreur ou IP nulle.
  observe({
    req(session$clientData$url_hostname)
    fetch_client_ip(session)
  })


  # ══════════════════════════════════════════════════════════════════════════
  # ── Connexion (login) ─────────────────────────────────────────────────────
  # ══════════════════════════════════════════════════════════════════════════
  #
  # Ordre des vérifications — intentionnel :
  #   1. Verrou brute force       → sans appel S3 (économie de ressources)
  #   2. Champs non vides         → validation locale avant tout appel réseau
  #   3. Lecture S3               → un seul appel pour toutes les vérifications suivantes
  #   4. Username existant        → avant bcrypt (inutile de hasher pour personne)
  #   5. Compte actif             → avant bcrypt (idem)
  #   6. Date d'expiration        → avant bcrypt (idem)
  #   7. Vérification bcrypt      → délibérément en dernier (~100ms, intentionnellement lent)
  observeEvent(input$login, {
    just_logged_out(FALSE)

    # ── 1. Vérification du verrou brute force ──────────────────────────────
    # Si l'utilisateur a dépassé le seuil de tentatives, on bloque immédiatement
    # SANS lire S3 — économise une requête réseau et décourage les bots.
    # Le message affiche le temps restant pour que l'UX soit claire.
    failures <- login_failures()
    if (!is.null(failures$locked_until) && Sys.time() < failures$locked_until) {
      secs_remaining <- ceiling(as.numeric(difftime(failures$locked_until, Sys.time(), units = "secs")))
      sendSweetAlert(
        session,
        title = "Oops!",
        text  = sprintf(tr("too_many_attempts"), secs_remaining),
        type  = "error"
      )
      return(NULL)
    }

    # ── 2. Validation des champs non vides ─────────────────────────────────
    # trimws() supprime les espaces en début/fin — évite les username " admin"
    # qui passeraient la validation mais ne correspondraient à aucun utilisateur.
    # Vérification serveur indispensable : on ne fait jamais confiance au client.
    if (trimws(input$username) == "" || trimws(input$password) == "") {
      sendSweetAlert(session, "Oops!", tr("empty_fields"), "error")
      return(NULL)
    }

    # ── 3. Lecture de la base utilisateurs ────────────────────────────────
    # S3/postgres : lecture à chaque tentative (pas de cache) pour que les
    # modifications soient effectives immédiatement sans redémarrer l'app.
    # Local : data.frame déjà en mémoire dans config_global — aucun appel réseau.
    users_info <- if ((config_global$protegR2$user_config_backend %||% "none") == "local") {
      config_global$protegR2$local_users_auth
    } else {
      s3readRDS_HL(object = "config_files/users_auth.rds")
    }

    # ── 4. Vérification de l'existence du username ─────────────────────────
    # trimws() appliqué ici aussi : cohérence avec la validation précédente.
    # nrow() == 1 (et non > 0) : un username doit être unique. Si pour une
    # raison quelconque il y avait un doublon, on refuse aussi.
    #
    # Message GÉNÉRIQUE intentionnel : on ne dit pas si c'est le username ou
    # le password qui est faux — un attaquant ne peut pas ainsi "confirmer"
    # que le username existe. C'est une bonne pratique de sécurité standard.
    valid_user_df <- users_info %>% filter(username == trimws(input$username))
    if (nrow(valid_user_df) != 1) {
      login_failures(increment_failures(failures))
      sendSweetAlert(session, "Oops!", tr("invalid_credentials"), "error")
      return(NULL)
    }

    valid_user <- as.list(valid_user_df)

    # ── 5. Vérification du compte actif ───────────────────────────────────
    # La colonne "active" dans users_auth.rds peut être mise à FALSE par un admin
    # pour suspendre un utilisateur sans le supprimer.
    # Ici on affiche un message différent de "invalid_credentials" parce qu'on veut
    # que l'utilisateur comprenne qu'il doit contacter son admin — pas qu'il retape.
    if (!valid_user$active) {
      sendSweetAlert(session, "Oops!", tr("inactive_account"), "error")
      return(NULL)
    }

    # ── 6. Vérification de la date d'expiration ───────────────────────────
    # is.na() d'abord : si expire_date est NA, le compte n'expire jamais.
    # L'opérateur && (court-circuit) : si is.na() est TRUE, la 2e condition
    # n'est pas évaluée — évite une comparaison NA < Date qui retournerait NA.
    if (!is.na(valid_user$expire_date) && valid_user$expire_date < Sys.Date()) {
      sendSweetAlert(session, "Oops!", tr("expired_account"), "error")
      return(NULL)
    }

    # ── 7. Vérification bcrypt du mot de passe ────────────────────────────
    # password_verify() de {sodium} compare input$password au hash bcrypt stocké.
    # Le hash bcrypt contient le salt intégré — password_verify() le extrait et
    # refait le hash pour comparer. C'est délibérément lent (~100-300ms) pour
    # rendre le brute force coûteux même si quelqu'un accède directement aux hashes.
    #
    # On met cette vérification EN DERNIER pour ne payer ce coût que si toutes
    # les vérifications précédentes (gratuites) ont passé.
    if (!password_verify(valid_user$hash_password, input$password)) {
      login_failures(increment_failures(failures))
      sendSweetAlert(session, "Oops!", tr("invalid_credentials"), "error")
      return(NULL)
    }

    # ── 8. Vérification d'accès au host restreint ──────────────────────────
    # Doit être après bcrypt (on ne révèle pas pourquoi on refuse si le mdp
    # est mauvais) et avant user_auth() (on n'ouvre pas la session si refusé).
    if (!check_host_access(valid_user)) return(NULL)

    # ── 9. Login réussi — toutes les vérifications ont passé ──────────────
    # Réinitialisation du compteur d'échecs (nouveau départ propre).
    login_failures(list(count = 0, locked_until = NULL))

    # Génération du token de session : UUID v4 = 122 bits aléatoires.
    # use.time = FALSE → purement aléatoire, sans composante temporelle.
    # Ce token identifie la session côté S3 : session/{token}.rds
    token_value <- UUIDgenerate(use.time = FALSE)

    # session$user et sessions[] sont des mécanismes de suivi des sessions actives.
    # sessions est un environnement global (défini dans global.R) qui liste
    # toutes les sessions Shiny en cours. Utilisé par perform_logout() pour
    # envoyer un message forceDisconnect aux autres sessions du même utilisateur.
    session$user <- input$username
    sessions[[session$token]] <- list(session = session, valid_user_df = valid_user_df)

    # Suppression des anciens tokens S3 de cet utilisateur.
    # Effet : invalide toutes ses sessions précédentes (autre appareil/navigateur).
    # C'est le mécanisme "Option B" de détection de session simultanée :
    # la session précédente découvrira au prochain cycle (45s) que son token
    # n'existe plus sur S3 et se déconnectera automatiquement.
    cookie_validator_delete(input$username, session)

    # perform_login() centralise :
    #   - La mise à jour de session$userData$user_info (valid_user, token, role)
    #   - La création du fichier de session sur S3
    #   - L'enregistrement du cookie dans le navigateur
    perform_login(valid_user, token_value, input, session)

    # ── user_auth() : le déclencheur de la bascule login → app ────────────
    # C'est LA ligne qui fait disparaître la page de login et afficher l'app.
    # output$main_ui (renderUI) lit user_auth() — quand il passe de NULL à
    # une valeur, Shiny ré-exécute renderUI et affiche l'application.
    #
    # Pourquoi ici et pas dans perform_login() ?
    # Pour garder perform_login() réutilisable (auto-login, tests, etc.) sans
    # couplage à la structure UI de ce serveur spécifique. La responsabilité
    # de "changer ce qui est affiché" appartient au serveur, pas à une fonction helper.
    session$userData$user_info$user_auth(valid_user$username)
  })


  # ══════════════════════════════════════════════════════════════════════════
  # ── Déconnexion (logout) ──────────────────────────────────────────────────
  # ══════════════════════════════════════════════════════════════════════════
  #
  # observeEvent sur input$logout : le bouton "Déconnexion" est rendu dans
  # output$main_ui quand l'utilisateur est connecté. Shiny reconnaît les inputs
  # même s'ils sont créés dynamiquement par renderUI — aucun traitement spécial
  # nécessaire de notre côté.
  #
  # perform_logout() gère :
  #   - Suppression du fichier de session S3 (token invalide immédiatement)
  #   - Suppression des tokens expirés d'autres utilisateurs (nettoyage)
  #   - Envoi du message forceReload aux sessions concurrentes du même user
  #   - Suppression du cookie navigateur
  #   - Remise à NULL de user_auth() → bascule retour vers la page de login
  observeEvent(input$logout, {
    just_logged_out(TRUE)
    perform_logout(session = session)
  })


  # ══════════════════════════════════════════════════════════════════════════
  # ── Auto-login via cookie ─────────────────────────────────────────────────
  # ══════════════════════════════════════════════════════════════════════════
  #
  # observe() sans déclencheur explicite — ses dépendances réactives implicites :
  #   - just_logged_out()                          → bloque après logout
  #   - session$userData$user_info$user_auth()     → évite de relancer si connecté
  #   - input$cookies (via cookie_auto_login)      → mis à jour par add_cookie_handlers()
  #
  # Shiny détecte ces dépendances automatiquement à la première exécution et
  # ré-exécute le bloc chaque fois qu'une d'elles change.
  #
  # Flux d'exécution :
  #   1. Au démarrage (juste_logged_out = FALSE, user_auth = NULL) → tente auto-login
  #   2. cookie_auto_login() lit le cookie du navigateur et vérifie S3 :
  #      - Cookie absent ou expiré ou fingerprint différent → retourne NULL → rien
  #      - Cookie valide → retourne la ligne S3 du token → on connecte l'utilisateur
  #   3. Après logout → just_logged_out() est TRUE → le if() ne s'exécute pas
  #   4. Après login (manuel ou auto) → user_auth() n'est plus NULL → le if() ne s'exécute pas
  observe({
    if (!just_logged_out() && is.null(session$userData$user_info$user_auth())) {

      S3_save_cookie_valid <- cookie_auto_login(input = input, session = session)

      if (!is.null(S3_save_cookie_valid)) {

        # Rechargement des données utilisateur pour avoir les infos à jour.
        # Local : déjà en mémoire. S3 : lecture sans cache.
        all_users_df  <- if ((config_global$protegR2$user_config_backend %||% "none") == "local") {
          config_global$protegR2$local_users_auth
        } else {
          s3readRDS_HL(object = "config_files/users_auth.rds")
        }
        valid_user_df <- all_users_df %>%
          filter(username == S3_save_cookie_valid[[1, "username"]])
        valid_user <- as.list(valid_user_df)

        # Même vérification d'accès qu'au login manuel.
        # Si l'utilisateur n'a plus dev_access (flag retiré par le dev pendant
        # une session active), il sera bloqué au prochain auto-login (refresh).
        if (!check_host_access(valid_user)) return(invisible(NULL))

        session$user      <- valid_user$username
        sessions[[session$token]] <- list(session = session, valid_user_df = valid_user_df)

        # On réutilise le token du cookie (pas de nouveau token) — l'auto-login
        # prolonge la session existante, il ne crée pas une nouvelle session.
        perform_login(
          valid_user  = valid_user,
          token_value = S3_save_cookie_valid[[1, "token_value"]],
          input       = input,
          session     = session
        )

        # Même logique qu'au login manuel : déclenche la bascule login → app.
        session$userData$user_info$user_auth(valid_user$username)
      }
    }
  })


  # ══════════════════════════════════════════════════════════════════════════
  # ── Rendu principal : login ou application ────────────────────────────────
  # ══════════════════════════════════════════════════════════════════════════
  #
  # ══════════════════════════════════════════════════════════════════════════
  # ── Rendu principal : login ou application ────────────────────────────────
  # ══════════════════════════════════════════════════════════════════════════
  #
  # output$main_ui : le point central de la bascule login ↔ application.
  #
  # renderUI() est ré-exécuté automatiquement quand user_auth() change.
  #   - user_auth() == NULL → page de login (card centrée, sans navigation)
  #   - user_auth() != NULL → layout retourné par protegR2_load_modules_UIs()
  #
  # Architecture "layout dans le projet" :
  #   protegR2_load_modules_UIs() vit dans R/ du projet (copié par
  #   protegR2_init_layout()). Elle retourne la structure de page COMPLÈTE :
  #   navset_pill_list(), page_navbar(), tagList(gear, page_fillable()), etc.
  #   protegR2_server() ne connaît pas le style — il rend ce qu'il reçoit.
  #
  # Convention contractuelle entre ce fichier et le template :
  #   Le composant de navigation doit utiliser id = "nav_tab" pour que
  #   l'observeEvent ci-dessous puisse mettre à jour l'URL.
  #
  # Restauration de l'onglet actif :
  #   Les templates lisent isolate(getQueryString(session))$page directement
  #   dans protegR2_load_modules_UIs() — aucun paramètre à passer ici.
  output$main_ui <- renderUI({

    if (is.null(session$userData$user_info$user_auth())) {

      # ── Page de login ────────────────────────────────────────────────────────
      # Structure indépendante : card centrée, sans navbar ni sidebar.
      # config_global lu depuis session$userData (capturé au démarrage)
      # pour éviter l'évaluation paresseuse depuis le namespace du package.
      .login_ui(session$userData$config_global, tr = tr)

    } else {

      # ── Application connectée ──────────────────────────────────────────────
      #
      # Le bouton logout est géré ici (et non dans le template) car c'est une
      # fonctionnalité core de protegR2 — garantit sa présence quel que soit
      # le layout choisi par l'utilisateur.
      #
      # z-index 9998 : sous le sélecteur de langue (9999), au-dessus du contenu.
      # right: 140px laisse la place au sélecteur de langue (110px + marge).
      tagList(

        div(
          class = "protegr2-logout-fixed",
          style = "position: fixed; top: 10px; right: 140px; z-index: 9998;",
          actionButton(
            "logout",
            label = tagList(icon("right-from-bracket"), tr("logout")),
            class = "btn-outline-secondary btn-sm"
          )
        ),

        # Layout complet retourné par le template R/ du projet.
        # Peut être navset_pill_list(), page_navbar(), page_fillable(), etc.
        .load_modules_UIs(session, tr)

      )
    }
  })


  # ══════════════════════════════════════════════════════════════════════════
  # ── Sauvegarde de la page active dans l'URL ───────────────────────────────
  # ══════════════════════════════════════════════════════════════════════════
  #
  # Objectif : écrire le panel actif dans l'URL à chaque navigation, pour
  # pouvoir le restaurer au refresh ou après un auto-login par cookie.
  #
  # updateQueryString("?page=valeur", mode = "push") :
  #   - "push"    → ajoute une entrée dans l'historique du navigateur
  #                 (le bouton "précédent" fonctionne)
  #   - "replace" → remplace l'entrée courante sans créer d'historique
  #   On choisit "push" pour ne pas casser la navigation navigateur.
  #
  # req(user_auth()) : on n'écrit dans l'URL que si l'utilisateur est
  # connecté. Sur la page de login, input$nav_tab n'existe pas (le navset
  # n'est pas rendu), donc ce bloc ne se déclenche pas de toute façon —
  # mais req() le rend explicite et sûr.
  observeEvent(input$nav_tab, {
    req(session$userData$user_info$user_auth())
    updateQueryString(
      paste0("?page=", input$nav_tab),
      mode    = "push",
      session = session
    )
  })


  # ══════════════════════════════════════════════════════════════════════════
  # ── Refresh du cookie d'activité ──────────────────────────────────────────
  # ══════════════════════════════════════════════════════════════════════════
  #
  # Objectif : maintenir la session active tant que l'utilisateur interagit
  # avec l'application. Sans refresh, le cookie expirerait après inactivity_delay
  # minutes même si l'utilisateur est actif.
  #
  # Mécanisme throttle() :
  #   reactive(reactiveValuesToList(input)) crée un reactive qui "écoute" TOUS
  #   les inputs Shiny en même temps. Il se déclenche à chaque interaction
  #   (clic, saisie, slider, etc.).
  #   throttle(cookie_throttle_ms) limite la fréquence : même si l'utilisateur
  #   clique 1000 fois par minute, ce bloc s'exécute AU MAXIMUM toutes les
  #   cookie_throttle_ms millisecondes (défaut : 240 000 ms = 4 minutes).
  #   Pourquoi 4 min ? Pour éviter de bombarder S3 à chaque frappe de touche.
  #   Le cookie est valide pendant inactivity_delay minutes (ex. 60 min) — le
  #   rafraîchir toutes les 4 min est largement suffisant.
  #
  # throttle() est différent de debounce() :
  #   - throttle : s'exécute immédiatement puis attend N ms avant de pouvoir
  #     s'exécuter à nouveau ("rate limiting")
  #   - debounce : attend N ms d'inactivité avant de s'exécuter ("trailing edge")
  #   On veut throttle ici pour réagir rapidement à la première interaction.
  #
  # La valeur est lue depuis config_global (accessible ici via la closure de
  # protegR2_server — session$userData$config_global est déjà initialisé à ce
  # stade). throttle() évalue son argument une seule fois à la création du
  # reactive, donc on l'extrait d'abord dans une variable locale.
  cookie_throttle_ms <- session$userData$config_global$protegR2$security$cookie_throttle_ms %||% 240000
  throttled_inputs   <- reactive(reactiveValuesToList(input)) %>% throttle(cookie_throttle_ms)

  observeEvent(throttled_inputs(), {

    # req() : ne s'exécute que si l'utilisateur est connecté.
    # Sans ça, le bloc s'exécuterait aussi sur la page de login à chaque frappe
    # dans les champs username/password — inutile et coûteux.
    req(session$userData$user_info$user_auth())

    now         <- Sys.time()
    token_value <- session$userData$user_info$token_value
    backend     <- config_global$protegR2$user_config_backend %||% "none"
    pool        <- session$userData$pool

    # ── Vérification que la session est encore valide ────────────────────────
    #
    # Si le token a disparu ou est expiré → déconnexion (autre login détecté).
    # Si valide → on prolonge l'expiration (cookie_set_user gère les deux backends).
    session_valide <- if (backend == "postgres" && !is.null(pool)) {
      result <- DBI::dbGetQuery(pool,
        "SELECT expiration FROM protegr2.sessions WHERE token_value = $1",
        list(token_value)
      )
      nrow(result) == 1 && result$expiration[1] > now
    } else if (backend == "local") {
      # Vérification en mémoire — aucun appel réseau
      exists(token_value, envir = .local_sessions) &&
        .local_sessions[[token_value]]$expiration > now
    } else {
      file_path <- paste0("session/", token_value, ".rds")
      s3exist_HL(object = file_path) &&
        s3readRDS_HL(object = file_path) %>% pull(expiration) >= now
    }

    if (!session_valide) {
      just_logged_out(TRUE)
      session$userData$user_info$user_auth(NULL)
    } else {
      # Session valide : prolonger l'expiration (S3 ou postgres via cookie_set_user)
      cookie_set_user(input, session)
      session$userData$timestamp_cookie_reset(now)
    }
  })


  # ══════════════════════════════════════════════════════════════════════════
  # ── Vérification du token S3 toutes les 45 secondes ───────────────────────
  # ══════════════════════════════════════════════════════════════════════════
  #
  # Rôle : détecter en moins d'une minute qu'une autre session a invalidé ce
  # token (connexion simultanée sur un autre appareil — mécanisme Option B).
  #
  # ── Pourquoi S3 et non get_cookie() ? ─────────────────────────────────────
  #
  # get_cookie() lit input$cookies, qui est une SNAPSHOT du navigateur au
  # moment du chargement initial de la page. Quand set_cookie() est appelé
  # pendant la session (au login, au refresh), input$cookies ne se met PAS
  # à jour — il reste figé sur la valeur présente au chargement de la page.
  #
  # Conséquence concrète :
  #   1. Utilisateur arrive → page se charge → input$cookies = {} (vide)
  #   2. Utilisateur se connecte → set_cookie() pose le cookie dans le navigateur
  #   3. user_auth() devient non-NULL → cet observe se déclenche immédiatement
  #   4. get_cookie() lirait input$cookies → toujours {} → retournerait NULL
  #   5. Résultat : fausse déconnexion automatique juste après le login !
  #
  # En vérifiant S3 à la place, on est toujours cohérent :
  #   - Token présent sur S3 → session valide (même juste après login)
  #   - Token absent sur S3  → soit expiré, soit remplacé par un autre login
  #
  # ── Comment invalidateLater fonctionne ici ─────────────────────────────────
  #
  # Ce bloc s'exécute une première fois immédiatement quand user_auth() passe
  # de NULL à une valeur (déclencheur réactif). À ce moment, le token vient
  # d'être écrit sur S3 → s3exist_HL() retourne TRUE → rien ne se passe.
  # Ensuite, invalidateLater(token_check_interval_ms) programme une ré-exécution
  # toutes les N secondes (défaut : 45s = 45 000 ms), puis N secondes après
  # celle-là, etc. — boucle infinie jusqu'à la fermeture de la session ou la
  # déconnexion (req() stopperait le cycle si user_auth redevient NULL).
  #
  # L'intervalle est lu depuis config_global$protegR2$security$token_check_interval_s
  # (en secondes, converti en ms pour invalidateLater).
  observe({
    req(session$userData$user_info$user_auth())
    token_check_ms <- (session$userData$config_global$protegR2$security$token_check_interval_s %||% 45) * 1000
    invalidateLater(token_check_ms)

    token_value <- session$userData$user_info$token_value
    req(token_value)

    backend <- config_global$protegR2$user_config_backend %||% "none"
    pool    <- session$userData$pool

    # ── Vérification que le token existe encore côté serveur ──────────────────
    #
    # Si le token a disparu (autre login → cookie_validator_delete() l'a supprimé,
    # ou expiration naturelle), on invalide la session locale.
    # On n'appelle PAS perform_logout() ici — on coupe seulement la session courante.
    #
    # Ordre intentionnel :
    #   1. just_logged_out(TRUE)  → bloque l'auto-login pendant que le popup s'affiche
    #   2. sendCustomMessage(...) → affiche le popup (asynchrone côté client)
    #   3. user_auth(NULL)        → bascule vers la page de login
    token_existe <- if (backend == "postgres" && !is.null(pool)) {
      result <- DBI::dbGetQuery(pool,
        "SELECT COUNT(*) AS n FROM protegr2.sessions WHERE token_value = $1",
        list(token_value)
      )
      result$n > 0
    } else if (backend == "local") {
      # Vérification en mémoire — token présent et non expiré
      exists(token_value, envir = .local_sessions) &&
        .local_sessions[[token_value]]$expiration > Sys.time()
    } else {
      file_path <- paste0("session/", token_value, ".rds")
      s3exist_HL(object = file_path)
    }

    if (!token_existe) {
      just_logged_out(TRUE)
      session$sendCustomMessage("forceDisconnect", list(
        message = "Votre session a ete ouverte sur un autre appareil. Vous avez ete deconnecte."
      ))
      session$userData$user_info$user_auth(NULL)
    }
  })


  # ══════════════════════════════════════════════════════════════════════════
  # ── Nettoyage à la fermeture de session ───────────────────────────────────
  # ══════════════════════════════════════════════════════════════════════════
  #
  # onSessionEnded() est un callback appelé par Shiny quand la connexion
  # WebSocket entre le navigateur et le serveur est fermée (fermeture d'onglet,
  # navigation vers une autre page, perte de réseau, etc.).
  #
  # Important : à ce moment, les valeurs réactives ne sont plus accessibles.
  # On peut seulement utiliser des valeurs non réactives — c'est pourquoi on
  # utilise session$user (non réactif) et session$token (non réactif).
  #
  # Pourquoi ne pas appeler perform_logout() ici ?
  # perform_logout() fait des appels S3 et utilise des reactiveVal — non
  # disponibles après onSessionEnded. On fait juste le nettoyage minimal :
  # supprimer l'entrée dans l'objet global "sessions". Le fichier S3 expirera
  # naturellement ou sera supprimé au prochain login de cet utilisateur.
  session$onSessionEnded(function() {
    if (!is.null(session$user)) {
      rm(list = session$token, envir = sessions)
    }
  })

}

# ── Fonctions définies dans le projet utilisateur, pas dans le package ────────
#
# Ces trois fonctions sont intentionnellement absentes du package protegR2.
# Elles sont copiées dans le dossier R/ du projet utilisateur lors de
# l'initialisation (protegR2_copy_files()), car elles sont conçues pour
# être personnalisées par projet :
#
#   protegR2_login_ui()            → apparence de la page de login (logo, fond, couleurs)
#   protegR2_load_modules_UIs()    → liste des nav_panel() selon le rôle utilisateur
#   protegR2_load_modules_servers()→ démarrage des modules Shiny du projet
#
# R CMD check signalerait "no visible global function definition" pour ces noms,
# car il n'a pas accès au code du projet utilisateur. utils::globalVariables()
# supprime cet avertissement en déclarant explicitement que ces noms sont connus
# et définis dans un environnement externe au package.
#
# C'est le mécanisme standard prévu par R pour exactement ce cas de figure.
# Voir aussi : utils::globalVariables() dans perform_login_logout.R pour
# le même patron appliqué à d'autres variables externes.
utils::globalVariables(c(
  "protegR2_login_ui",
  "protegR2_load_modules_UIs",
  "protegR2_load_modules_servers"
))

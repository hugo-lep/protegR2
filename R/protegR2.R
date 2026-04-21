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
#' @importFrom shiny uiOutput tags div selectInput HTML
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
    bootswatch = config_global$bootswatch %||% "darkly",
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
      useShinyjs(),   #active fonction javascript (toogle,hide,show), doit être appeler 1x dans ui

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
#'
#' @importFrom bslib navset_pill_list navset_underline navset_tab navset_card_underline
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
#'
#' @export
protegR2_server <- function(input, output, session, style = "sidebar") {

  # ── Fonction helper locale : incrément du compteur de brute force ──────────
  #
  # Règle de verrouillage :
  #   Tentatives 1–4 : compteur incrémenté, pas de verrou
  #   Tentative 5+   : verrou de 30 secondes
  # Le verrou est local à la session — il disparaît si l'utilisateur ferme
  # et rouvre l'onglet. Un verrou persistant sur S3 est prévu en Phase 2.6.
  increment_failures <- function(failures) {
    new_count    <- failures$count + 1
    locked_until <- if (new_count >= 5) Sys.time() + 30 else NULL
    list(count = new_count, locked_until = locked_until)
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

  session$userData$config_s3_location     <- config_s3_location
  session$userData$config_global          <- config_global
  session$userData$style                  <- style
  session$userData$timestamp_cookie_check <- reactiveVal(Sys.time())
  session$userData$timestamp_cookie_reset <- reactiveVal(Sys.time())

  session$userData$idioma <- reactiveVal(config_global$idioma %||% "fr")

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

    # ── 3. Lecture de la base utilisateurs sur S3 ──────────────────────────
    # Lecture à chaque tentative (pas de cache) pour que les modifications
    # d'accès soient effectives immédiatement sans redémarrer l'application.
    # Ex. : un admin désactive un compte → effectif au prochain essai de login.
    users_info <- s3readRDS_HL(object = "config_files/users_auth.rds")

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

    # ── 8. Login réussi — toutes les vérifications ont passé ──────────────
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

        # Rechargement des données utilisateur depuis S3 pour avoir les
        # informations à jour (rôle, actif, expiration) — pas de cache ici.
        valid_user_df <- s3readRDS_HL(object = "config_files/users_auth.rds") %>%
          filter(username == S3_save_cookie_valid[[1, "username"]])
        valid_user        <- as.list(valid_user_df)
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
  # my_panels est un reactive() (pas un reactiveVal) :
  #   - reactive() = expression réactive qui CALCULE et CACHE son résultat
  #   - Elle se ré-exécute uniquement si ses dépendances changent
  #   - Ici la dépendance est user_role() : les panels changent selon le rôle
  #   - Pourquoi un reactive() séparé et pas tout dans renderUI ?
  #     Pour que la liste de panels ne soit recalculée que si le rôle change —
  #     pas à chaque re-rendu de main_ui (qui peut se déclencher pour d'autres
  #     raisons comme le changement de langue).
  #
  # req(user_role()) : garde réactive — si le rôle n'est pas encore défini
  # (par exemple au démarrage avant auto-login), on attend sans erreur.
  my_panels <- reactive({
    req(session$userData$user_info$user_role())
    .load_modules_UIs(session, tr)
  })

  # output$main_ui : le point central de la bascule login ↔ application.
  #
  # renderUI() est ré-exécuté automatiquement quand user_auth() change.
  # C'est la dépendance réactive clé de tout le système d'authentification :
  #   - user_auth() == NULL → page de login (structure bslib minimale)
  #   - user_auth() != NULL → application complète avec navigation
  #
  # do.call(fonction, c(liste_d_args_fixes, liste_de_panels)) :
  #   navset_pill_list(id = "nav_tab", well = FALSE, panel1, panel2, panel3, ...)
  # On ne peut pas écrire navset_pill_list(id = ..., my_panels()) directement
  # parce que my_panels() retourne UNE LISTE, pas des arguments séparés.
  # do.call() "déplie" la liste en arguments individuels — c'est l'équivalent
  # du spread operator (...) dans JavaScript ou Python.
  output$main_ui <- renderUI({

    if (is.null(session$userData$user_info$user_auth())) {

      # ── Page de login ──────────────────────────────────────────────────────
      # Structure indépendante : aucun sidebar, aucune navbar — juste la card
      # centrée. bslib permet ce changement complet de structure sans conflit CSS
      # parce que chaque état est rendu à l'intérieur du même page_fluid().
      .login_ui(config_global, tr = tr)

    } else {

      # ── Application connectée ──────────────────────────────────────────────

      # ── Restauration de la page active ──────────────────────────────────────
      # Calculé ICI, avant le tagList(), car une assignation R ne peut pas
      # figurer à l'intérieur d'un tagList() (qui n'accepte que des éléments UI).
      #
      # isolate() lit l'URL sans créer de dépendance réactive.
      # Sans isolate(), chaque updateQueryString() (déclenché à chaque
      # changement d'onglet) invaliderait renderUI → boucle infinie.
      #
      # Ce bloc s'exécute à chaque re-rendu de main_ui, notamment :
      #   - Au login (manuel ou auto) : restaure la page sauvegardée dans l'URL
      #   - Au changement de langue   : my_panels() se recalcule → re-rendu →
      #     l'URL contient toujours la page active → onglet préservé
      #
      # Si l'URL ne contient pas de ?page= (première connexion, ou valeur inconnue),
      # saved_page vaut NULL et bslib sélectionne le premier panel par défaut.
      #
      # Convention : pour que la restauration survive au changement de langue,
      # les nav_panel() dans protegR2_load_modules_UIs.R doivent utiliser un
      # argument value= stable (indépendant de la langue) :
      #   nav_panel(title = tr("rapports"), value = "rapports", ...)
      saved_page <- isolate(getQueryString(session))$page

      tagList(

        # Bouton de déconnexion en position fixe — visible sur toutes les pages.
        # z-index 9998 : en dessous du sélecteur de langue (9999) mais au-dessus
        # de tous les éléments de contenu. right: 140px laisse la place au
        # sélecteur de langue (110px de large + 15px de marge + marge supplémentaire).
        div(
          style = "position: fixed; top: 10px; right: 140px; z-index: 9998;",
          actionButton(
            "logout",
            label = tagList(icon("right-from-bracket"), tr("logout")),
            class = "btn-outline-secondary btn-sm"
          )
        ),

        # Dispatch du layout selon le style choisi dans global.R / server.R.
        # Chaque navset_* reçoit la même liste de nav_panel() — seule la
        # présentation visuelle change (sidebar vs onglets horizontaux vs etc.)
        #
        # L'id "nav_tab" permet de lire l'onglet actif via input$nav_tab et
        # de le changer programmatiquement via nav_select("nav_tab", "valeur").
        switch(style,

          "sidebar" = do.call(
            navset_pill_list,
            c(list(id = "nav_tab", well = FALSE, selected = saved_page), my_panels())
            # well = FALSE : supprime l'arrière-plan gris qui encadre la liste
            # par défaut dans navset_pill_list — rendu plus propre
          ),

          "navbar" = do.call(
            navset_underline,
            c(list(id = "nav_tab", selected = saved_page), my_panels())
            # navset_underline : onglets horizontaux avec soulignement actif
            # (plus moderne que navset_tab qui utilise des onglets avec bordure)
          ),

          "fluid" = do.call(
            navset_tab,
            c(list(id = "nav_tab", selected = saved_page), my_panels())
            # navset_tab : onglets classiques Bootstrap dans une page fluid
          ),

          "fillable" = do.call(
            navset_card_underline,
            c(list(id = "nav_tab", selected = saved_page), my_panels())
            # navset_card_underline : onglets avec card plein écran — idéal
            # pour les dashboards avec graphiques qui occupent tout l'espace
          )
        )
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
  #   throttle(240000) limite la fréquence : même si l'utilisateur clique
  #   1000 fois par minute, ce bloc s'exécute AU MAXIMUM toutes les 4 minutes.
  #   Pourquoi 4 min ? Pour éviter de bombarder S3 à chaque frappe de touche.
  #   Le cookie est valide pendant inactivity_delay minutes (ex. 60 min) — le
  #   rafraîchir toutes les 4 min est largement suffisant.
  #
  # throttle() est différent de debounce() :
  #   - throttle : s'exécute immédiatement puis attend N ms avant de pouvoir
  #     s'exécuter à nouveau ("rate limiting")
  #   - debounce : attend N ms d'inactivité avant de s'exécuter ("trailing edge")
  #   On veut throttle ici pour réagir rapidement à la première interaction.
  throttled_inputs <- reactive(reactiveValuesToList(input)) %>% throttle(240000)

  observeEvent(throttled_inputs(), {

    # req() : ne s'exécute que si l'utilisateur est connecté.
    # Sans ça, le bloc s'exécuterait aussi sur la page de login à chaque frappe
    # dans les champs username/password — inutile et coûteux (appels S3).
    req(session$userData$user_info$user_auth())
    print("start cookie refresh")

    now         <- Sys.time()
    token_value <- session$userData$user_info$token_value
    file_path   <- paste0("session/", token_value, ".rds")

    # Double vérification : on vérifie que le fichier S3 existe ET qu'il n'est
    # pas expiré. Si le fichier manque, c'est qu'un autre login a créé un nouveau
    # token (détection session simultanée Option B). On déconnecte proprement.
    if (!s3exist_HL(object = file_path) ||
        s3readRDS_HL(object = file_path) %>% pull(expiration) < now) {
      print("cookie validator n'existe pas ou est expiré — déconnexion")
      just_logged_out(TRUE)
      session$userData$user_info$user_auth(NULL)
    } else {
      # Tout est valide : on prolonge la session en recréant le fichier S3
      # avec une nouvelle date d'expiration (maintenant + inactivity_delay).
      print("cookie validator valide — refresh du cookie")
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
  # Ensuite, invalidateLater(45000) programme une ré-exécution dans 45s,
  # puis 45s après celle-là, etc. — boucle infinie jusqu'à la fermeture de
  # la session ou la déconnexion (req() stopperait le cycle si user_auth redevient NULL).
  observe({
    req(session$userData$user_info$user_auth())
    invalidateLater(45000)

    print("vérification token S3 toutes les 45s")

    # req() sur token_value : sécurité pour ne pas appeler S3 avec un chemin
    # invalide si token_value n'est pas encore initialisé (cas théorique).
    token_value <- session$userData$user_info$token_value
    req(token_value)

    file_path <- paste0("session/", token_value, ".rds")

    if (!s3exist_HL(object = file_path)) {
      # Le token n'existe plus sur S3 :
      #   - Autre login avec ce username → cookie_validator_delete() a supprimé ce token
      #   - Token expiré et nettoyé manuellement
      # Dans les deux cas, on invalide la session côté Shiny.
      # On n'appelle PAS perform_logout() ici (qui supprimerait d'autres tokens
      # et enverrait des messages) — on se contente de couper la session locale.
      #
      # Ordre intentionnel des trois lignes ci-dessous :
      #   1. just_logged_out(TRUE)      → empêche l'observe d'auto-login de se déclencher
      #                                   pendant que le popup est affiché
      #   2. sendCustomMessage(...)     → envoie le popup au navigateur (non-bloquant
      #                                   côté serveur, asynchrone côté client)
      #   3. user_auth(NULL)            → invalide la session serveur immédiatement ;
      #                                   renderUI bascule vers la page de login, mais
      #                                   le handler JS forceDisconnect est dans tags$head
      #                                   (toujours présent) et s'exécutera quand même
      print("token S3 introuvable — session invalidee (expiration ou connexion simultanee)")
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

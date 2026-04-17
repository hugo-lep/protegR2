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

protegR2_server <- function(input, output, session, style = "sidebar") {

  # ── Fonction helper locale : incrément du compteur de brute force ──────────
  #
  # Cette fonction est définie ici (à l'intérieur de protegR2_server) plutôt
  # que dans un fichier séparé parce qu'elle est uniquement utile dans ce
  # contexte. En R, c'est parfaitement valide : une fonction peut contenir
  # d'autres fonctions, qui sont alors locales et invisibles de l'extérieur.
  #
  # Elle prend l'état actuel du compteur (une liste) et retourne un nouvel état.
  # Elle ne modifie PAS le reactiveVal directement — c'est le code appelant
  # qui fait login_failures(increment_failures(failures)). Ce choix de design
  # "fonction pure" (entrée → sortie, pas d'effet de bord) rend la logique
  # plus facile à tester et à comprendre.
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

  # reactiveVal(valeur_initiale) crée un "conteneur réactif" :
  #   - Pour lire  : session$userData$idioma()       ← noter les parenthèses
  #   - Pour écrire : session$userData$idioma("en")  ← appel comme une fonction
  # Quand on écrit dans un reactiveVal, tous les blocs qui le lisent sont
  # automatiquement ré-exécutés. C'est le mécanisme central de la réactivité Shiny.
  session$userData$idioma <- reactiveVal(config_global$idioma %||% "fr")

  # user_info est la liste centrale d'état de l'utilisateur connecté.
  # Chaque champ est un reactiveVal sauf token_value.
  #
  # Pourquoi token_value n'est PAS un reactiveVal ?
  # Parce qu'on ne veut pas que le changement du token force un re-rendu de l'UI.
  # Le token est une valeur interne de gestion de session — aucun élément visuel
  # ne doit "réagir" à son changement. C'est une simple valeur R, pas réactive.
  #
  # Les autres sont des reactiveVal parce que :
  #   - valid_user()  : des modules l'affichent (nom, email, rôle)
  #   - user_auth()   : contrôle la bascule login↔app dans output$main_ui
  #   - user_role()   : détermine quels onglets sont visibles dans my_panels()
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
  tr <- make_tr(i18n = i18n_db, lang = session$userData$idioma)

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

  # ── Chargement des modules serveur ────────────────────────────────────────
  # Défini dans protegR2_load_modules_servers.R (copié dans R/ du projet).
  # C'est ici qu'on démarre tous les modules Shiny du projet.
  # Les modules serveur doivent être appelés une fois, au démarrage de la session,
  # même si l'utilisateur n'est pas encore connecté — Shiny les met en attente.
  protegR2_load_modules_servers(sessions, input, session)

  # ── Changement de langue ──────────────────────────────────────────────────
  #
  # observeEvent(input$X, {...}) vs observe({req(input$X); ...}) :
  #   - observeEvent est plus lisible quand on réagit à un événement précis
  #   - Il n'exécute PAS le bloc au démarrage (ignoreInit = TRUE par défaut)
  #   - Il n'exécute pas si input$select_idioma est NULL (ignoreNULL = TRUE)
  #   - observe() s'exécute aussi au démarrage — utile pour les dépendances
  #     qui doivent être chargées dès le début (ex. IP, auto-login)
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
  # observeEvent(input$login, {...}) :
  #   - Se déclenche UNIQUEMENT sur un clic du bouton "login" ou Enter (via JS)
  #   - NE s'exécute PAS au démarrage (ignoreInit = TRUE par défaut)
  #   - NE s'exécute PAS si input$login est NULL (avant premier clic)
  #
  # Pattern "early return" :
  # Chaque vérification échoue avec return(NULL) dès qu'une condition n'est
  # pas remplie. C'est plus lisible et maintenable qu'un grand if/else imbriqué.
  # L'exécution ne continue que si TOUTES les vérifications passent.
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
    protegR2_load_modules_UIs(session, tr)
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
      protegR2_login_ui(config_global, tr = tr)

    } else {

      # ── Application connectée ──────────────────────────────────────────────
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
        # de le changer programmatiquement via nav_select("nav_tab", "Titre").
        # Utile pour la restauration de page au refresh (Phase 2.5).
        switch(style,

          "sidebar" = do.call(
            navset_pill_list,
            c(list(id = "nav_tab", well = FALSE), my_panels())
            # well = FALSE : supprime l'arrière-plan gris qui encadre la liste
            # par défaut dans navset_pill_list — rendu plus propre
          ),

          "navbar" = do.call(
            navset_underline,
            c(list(id = "nav_tab"), my_panels())
            # navset_underline : onglets horizontaux avec soulignement actif
            # (plus moderne que navset_tab qui utilise des onglets avec bordure)
          ),

          "fluid" = do.call(
            navset_tab,
            c(list(id = "nav_tab"), my_panels())
            # navset_tab : onglets classiques Bootstrap dans une page fluid
          ),

          "fillable" = do.call(
            navset_card_underline,
            c(list(id = "nav_tab"), my_panels())
            # navset_card_underline : onglets avec card plein écran — idéal
            # pour les dashboards avec graphiques qui occupent tout l'espace
          )
        )
      )
    }
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
  # ── Vérification du cookie toutes les 45 secondes ─────────────────────────
  # ══════════════════════════════════════════════════════════════════════════
  #
  # Rôle : détecter la disparition du cookie navigateur (fermeture d'onglet,
  # expiration, effacement manuel) et déconnecter proprement l'utilisateur.
  #
  # invalidateLater(45000) est la clé de ce mécanisme :
  #   Shiny traite les blocs observe() comme paresseux (lazy) — ils ne
  #   s'exécutent que quand une dépendance change. Sans invalidateLater(),
  #   ce bloc ne s'exécuterait jamais "tout seul" car le cookie navigateur
  #   n'est pas une dépendance réactive Shiny.
  #   invalidateLater(45000) force Shiny à ré-exécuter ce bloc dans 45 000 ms
  #   (45 secondes), en le marquant comme "invalidé" même sans changement de
  #   dépendance. C'est le seul moyen de faire du "polling" en Shiny.
  #
  # Fenêtre d'exposition :
  #   Entre 0 et 45 secondes après la disparition du cookie, la session est
  #   techniquement encore "active" côté Shiny. C'est acceptable — le fichier
  #   S3 a déjà expiré donc même si quelqu'un interceptait la session, le
  #   cookie qu'il aurait serait invalide pour l'auto-login.
  observe({
    req(session$userData$user_info$user_auth())
    invalidateLater(45000)

    print("vérification cookie d'activité")

    # get_cookie() lit le cookie depuis le navigateur (via {cookies}).
    # Si NULL : cookie absent → déconnexion propre via perform_logout().
    # perform_logout() supprime aussi le fichier S3 et le cookie côté serveur.
    if (is.null(get_cookie(config_global$cookie_name))) {
      print("cookie absent — déconnexion automatique")
      just_logged_out(TRUE)
      perform_logout(session = session)
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

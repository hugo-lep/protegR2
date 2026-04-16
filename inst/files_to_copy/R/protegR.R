print("protegR_ui")
protegR_ui <- function(config_global, idioma = TRUE) {

  add_cookie_handlers(
    dashboardPage(
      skin = config_global$dashboard_skin,
      #  dashboardHeader(title = uiOutput("dynamic_header")),
      dashboardHeader(title = config_global$header_title),
      dashboardSidebar(uiOutput("dynamic_sidebar")),
      dashboardBody(
                    useShinyjs(),  # ← ici, au début du body
                    # Dropdown conditionnel mais toujours visible si idioma = TRUE
                    if (idioma) {                                                          # à modifier pour idioma
                      div(
                        style = "
              position: absolute;
              top: 10px;
              right: 150px;
              width: 120px;
              z-index: 5000;
            ",
                        selectInput("select_idioma", NULL,
                                    choices = c("français" = "fr",
                                                "english" = "en",
                                                "español" = "es"),
                                    width = "120px")
                      )
                    },
                    tags$head(
                      # Cache les 3 lignes par défaut
                      tags$style(HTML("
        .main-header .sidebar-toggle:before {
          content: none !important;
        }
         /* Flèche fermée (remplace gauche par haut) */
        .sidebar-menu li > a .fa-angle-left {
          transform: rotate(90deg);
          transition: transform 0.2s;
        }
        /* Flèche quand menu est ouvert (par défaut vers bas) */
        .sidebar-menu li.active > a .fa-angle-left {
          transform: rotate(270deg);
        }
      ")),
                      # Ajoute une flèche gauche/droite selon l'état du sidebar
                      tags$script(HTML("
        $(document).on('shiny:connected', function() {
          function updateIcon() {
            if ($('body').hasClass('sidebar-collapse')) {
              $('.sidebar-toggle').html('<i class=\"fa fa-angle-right\"></i>');
            } else {
              $('.sidebar-toggle').html('<i class=\"fa fa-angle-left\"></i>');
            }
          }

          $('.sidebar-toggle').on('click', function() {
            setTimeout(updateIcon, 300);
          });

          updateIcon();
        });
      "))
                    ),
                    uiOutput("dynamic_body"))
    )
  )
}

print("protegR_server")

protegR_server <- function(input, output, session) {
  ns <- session$ns

  # * ------ AWS connect + load config --------------------------------------


  # APP CONTROL  -------------------------------------------------------
  # * ------ initialisation -------------------------------------------------
  session$userData$config_s3_location <- config_s3_location
  session$userData$config_global <- config_global
  session$userData$timestamp_cookie_check <- reactiveVal(Sys.time())
  session$userData$timestamp_cookie_reset <- reactiveVal(Sys.time())
  session$userData$user_info$token_value <- NULL
  session$userData$idioma <- reactiveVal("fr")

  session$userData$user_info <- list(
    valid_user = reactiveVal(NULL),
    token_value = NULL,
    user_auth = reactiveVal(NULL),  # uniquement cette partie est réactive
    user_role = reactiveVal(NULL)
  )

  tr <- make_tr(i18n = i18n_db,
                lang = session$userData$idioma)

  just_logged_out <- reactiveVal(FALSE) # pour éviter de lire les cookies au logout, juste avant qu'ils soient effacés

  # Fonction pour ne pas à devoir modifier ce fichier (load tous les modules utilisés par l'app)
  protegR_load_modules_servers(sessions, input, session)

  observeEvent(input$select_idioma, {
    session$userData$idioma(input$select_idioma)
  })


  # Traduction des différents inputs
  observe({
    input$select_idioma
    updateTextInput(session, "username", label =  tr("username"))
    updateTextInput(session, "password", label =  tr("password"))
    updateActionButton(session, "login", label = tr("login"))
    updateActionButton(session, "logout", label = tr("logout"))
  })

  # * ------ Lancer le fetch automatiquement au démarrage ------------------

  observe({
    # On attend que clientData soit disponible
    req(session$clientData$url_hostname)
    fetch_client_ip(session)
  })

  # * ------ login ----------------------------------------------------------
  observeEvent(input$login, {

    just_logged_out(FALSE)

    users_info <- s3readRDS_HL(object = "config_files/users_auth.rds")


    valid_user_df <- users_info %>%
      filter(username == input$username)

    # Vérifie que l'utilisateur existe
    if (nrow(valid_user_df) != 1) {
      sendSweetAlert(session, "Oops!", "Invalid username, please try again.", "error")
      return(NULL)
    }

    valid_user <- as.list(valid_user_df)

    # Vérifie si le compte toujour actif
    if (!valid_user$active) {
      sendSweetAlert(session, "Oops!", "Your user access is inactive!", "error")
      return(NULL)
    }

    # Vérifie si le compte est expiré (sauf si `no_expiration` est TRUE)
    if (!is.na(valid_user$expire_date) && valid_user$expire_date < Sys.Date()) {
      sendSweetAlert(session, "Oops!", "Your user access is expired!", "error")
      return(NULL)
    }

    # Vérifie le mot de passe
    if (!password_verify(valid_user$hash_password, input$password)) {
      sendSweetAlert(session, "Oops!", "Invalid credentials, please try again.", "error")
      return(NULL)
    }

    # Login valide : on génère un token et on lance la session
    token_value <- UUIDgenerate(use.time = FALSE)
    session$user <- input$username

    # Ajouter la session
    sessions[[session$token]] <- list(
      session    = session,
      valid_user_df = valid_user_df
    )


    cookie_validator_delete(input$username, session)
    perform_login(valid_user,
                  token_value,
                  input,
                  session)
  })

  observe({
    invalidateLater(1000)

    req(session$userData$user_info$valid_user())
    req(is.null(session$userData$user_info$user_auth()))

    cookie_val <- get_cookie(config_global$cookie_name)
    req(!is.null(cookie_val))

    session$userData$user_info$user_auth(
      session$userData$user_info$valid_user()$username
    )
    cat("user_auth mis à jour car cookie présent\n")
  })

  observeEvent(input$logout, {
    just_logged_out(TRUE)

    perform_logout(session = session)
  })

  # DYNAMIC DASHBOAD ----------------------------------------------
  # * ------ LOAD DATA -------------------------------------------------
  my_dashboard <- reactive({
    req(session$userData$user_info$user_role())

    protegR_load_modules_UIs(session, tr)
  })

  # pour resélectionner le même item dans le sidebarmenu après que la langue ait été changée
  observeEvent(session$userData$idioma(), {
    selected <- input$tabs  # id de ton sidebarMenu
    my_dashboard()          # force le recalcul
    updateTabItems(session, "tabs", selected)
  })


  # * ------ header construction ----------------------------------------------
  #  output$dynamic_header <- renderUI({
  #    if (is.null(session$userData$user_info$user_auth())) {
  #      dashboardHeader(title = "ProtegR DEMO")
  #    } else {
  #      NULL
  #    }
  #  })

  # * ------ sidebar construction ---------------------------------------------
  output$dynamic_sidebar <- renderUI({
    if (is.null(session$userData$user_info$user_auth())) {return(NULL)

    } else{
      do.call(sidebarMenu, append(list(id = ns("tabs")), my_dashboard()$menu_items))
    }
  })

  # * ------ Body construction ------------------------------------------------------

  output$dynamic_body <- renderUI({
    if (is.null(session$userData$user_info$user_auth())) {
      # Écran de login simple
      fluidPage(
        h2("Connexion"),
        protegR_login_ui(),

        tags$script(HTML("
  $(document).on('keydown', '#username, #password', function(e) {
    if (e.key === 'Enter') {
      $(this).blur();       // met à jour la valeur côté Shiny
      $('#login').click();  // déclenche le bouton
      e.preventDefault();
    }
  });
"))
      )
    } else {
      tagList(
        tags$head(
          # Icône par défaut (flèche vers la gauche)
          tags$style(HTML("
        .main-header .sidebar-toggle:before {
          content: none; /* Ne rien afficher par défaut */
        }
      ")),
          # Script pour changer l’icône selon l’état de la sidebar
          tags$script(HTML("
        $(document).on('shiny:connected', function() {
          function updateIcon() {
            if ($('body').hasClass('sidebar-collapse')) {
              $('.sidebar-toggle').html('<i class=\"fa fa-angle-right\"></i>');
            } else {
              $('.sidebar-toggle').html('<i class=\"fa fa-angle-left\"></i>');
            }
          }

          $('.sidebar-toggle').on('click', function() {
            setTimeout(updateIcon, 300); // attendre l'animation
          });

          updateIcon(); // initialisation
        });
      ")),
        tags$script(HTML("
    Shiny.addCustomMessageHandler('forceReload', function(message) {
      location.reload();   // recharge la page plutôt que griser
    });
  "))
      ),
      div(
        style = "
        position: absolute;
        top: 10px;
        right: 20px;
        z-index: 5000;
      ",
        actionButton("logout", "Logout", icon = icon("sign-out-alt"))
      ),
      do.call(tabItems, my_dashboard()$tab_items)
    )
    }
  })

  # ACTIVITIES/COOKIE -------------------------------------------------------
  # * ------ for cookie in config menu/ cookie refresh ----------------------

  # throttler les inputs pour réduire la fréquence de déclenchement
  throttled_inputs <- reactive(reactiveValuesToList(input)) %>% throttle(240000)   # 4 min

  observeEvent(throttled_inputs(), {
    req(session$userData$user_info$user_auth())
    print("start cookie refresh")

    now <- Sys.time()
    token_value <- session$userData$user_info$token_value
    file_path <- paste0("session/", token_value, ".rds")

    if (!s3exist_HL(object = file_path) |
          s3readRDS_HL(object = file_path) %>%
            pull(expiration) < now) {
      print("from cookie_activity_timestamp: cookie validator n'existe pas ou est expiré")
      just_logged_out(TRUE)
      session$userData$user_info$user_auth(NULL)

    } else {
      print("from cookie_activity_timestamp: *** il y a un cookie validator ***")
    }

    cookie_set_user(input, session)
    session$userData$timestamp_cookie_reset(now) #for info only, use in config menu/dev
    #    }
  })

  # * ------ for Quick check for inactivity (cookie) ----------------------
  observe({
    req(session$userData$user_info$user_auth())

    invalidateLater(45000)

    print("for Quick check for inactivity (cookie)")
    if (is.null(get_cookie(config_global$cookie_name))) {
      just_logged_out(TRUE)
      perform_logout(session = session)
      print("déconnexion si pas de cookie")
    } else {
      cat("cookie value: ", get_cookie(config_global$cookie_name), "\n")
    }
  })

  # * ------ login automatique si cookie -------------------------------------------------------------

  observe({
    print("########################## début du block auto-connect avec cookie #####################################")


    if (!just_logged_out() && is.null(session$userData$user_info$user_auth())) {   # << empêche de relire cookies si déconnecté volontairement
      S3_save_cookie_valid <-  cookie_auto_login(input = input, session = session)

      if (!is.null(S3_save_cookie_valid)) {
        valid_user_df <- s3readRDS_HL(object = "config_files/users_auth.rds") %>%
          filter(username == S3_save_cookie_valid[[1, "username"]])

        valid_user <- valid_user_df %>%
          as.list()

        session$user <- valid_user$username
        sessions[[session$token]] <- list(
          session    = session,
          valid_user_df = valid_user_df
        )

        perform_login(
          valid_user = valid_user,
          token_value = S3_save_cookie_valid[[1, "token_value"]],
          input = input,
          session = session
        )
      }
    }
  })
  # * ------ session fermé sans logout -------------------------------------------------------------
  session$onSessionEnded(function() {
    if (!is.null(session$user)) {
      rm(list = session$token, envir = sessions)
    }
  })
}

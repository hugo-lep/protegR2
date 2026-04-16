#' Menu de configuration disponible à tous
#'
#' @param id ID du module
#'
#' @importFrom shiny NS tagList fluidRow column
#' @importFrom shiny passwordInput actionButton
#'
#' @returns UI de configuration pour l'utilisateur
#' @export
#'
#' @examples
#' if(interactive()){
#' mod_config_ui1(id)
#' }
mod_config_ui1 <- function(id) {
  ns <- NS(id)

  tagList(
    # * ------ My account UI -------------------------------------------------------
    #    menuSubItem("my_account","my_account",
    fluidRow(column(offset = 1, width = 11,
                    passwordInput(ns("previous_password"), "Enter your previous password"))),
    fluidRow(column(offset = 1, width = 11,
                    passwordInput(ns("password1"), "Enter new password"))),
    fluidRow(column(offset = 1, width = 11,
                    passwordInput(ns("password2"), "Re-enter your new password"))),

    fluidRow(column(offset = 1, width = 11,
                    actionButton(ns("save_password"), "Save Password")))
    #    )
  )
}
# * ------ Admin UI ---------------------------------------------------------
utils::globalVariables(c(
  "tags"
))
#' Menu de configuration disponible à tous sauf utilisateur de base
#'
#' @description
#' Permet de créer de nouveaux utilisateurs et leur donner des accès
#' Un admin ne peux pas donner plus de privilège que ce qu'il détient lui-même
#'
#' @param id ID du module
#'
#' @importFrom shiny navbarPage tabPanel verbatimTextOutput
#' @importFrom shiny checkboxInput dateInput selectInput
#'
#' @returns UI pour la configuration admin
#' @export
#'
#' @examples
#' if(interactive()){
#' mod_config_ui2(id)
#' }
mod_config_ui2 <- function(id) {
  ns <- NS(id)

  tagList(
    navbarPage(
      "Admin menu:", id = ns("admin_menu"),
      tabPanel(
        title = "all_user", "all_user",
        verbatimTextOutput(ns("all_users"))
      ),
      # Onglet pour éditer un utilisateur existant
      tabPanel(
        title = "Edit User", "Edit User Info",

        fluidRow(column(6,
                        selectInput(ns("select_user"), "Select a User", choices = NULL),
                        fluidRow(checkboxInput(ns("user_enable"), "Enable User", value = NULL))),
                 column(6,
                        dateInput(ns("user_expiration"), "Expiration Date (YYYY-MM-DD)", value = NULL),
                        checkboxInput(ns("no_expiration"), "No Expiration", value = NULL))),
        fluidRow(
          column(6,
                 selectInput(ns("inactivity_delay"),
                             label = "Inactivity Delay",
                             selected = 15,
                             choices = c("5 min" = 5,
                                         "15 min" = 15,
                                         "30 min" = 30,
                                         "1 h" = 60,
                                         "2 h" = 120,
                                         "4 h" = 240,
                                         "8 h" = 480,
                                         "12 h" = 720))),
          column(6, fluidRow(actionButton(ns("user_info_save"), "Save User Info")))
        ),
        tags$hr(),
        h3("Change Password"),
        fluidRow(passwordInput(ns("password3"), "Enter New Password")),
        fluidRow(passwordInput(ns("password4"), "Re-enter New Password")),
        fluidRow(actionButton(ns("save_password2"), "Change Password"))
      ),
      # Onglet pour créer un nouvel utilisateur
      tabPanel(
        title = "Create User", "Create New User",
        fluidRow(textInput(ns("new_user"), "Username")),
        fluidRow(
          column(6, dateInput(ns("new_user_expiration"),
                              "Expiration Date (YYYY-MM-DD)",
                              value = NA)),
          column(6, checkboxInput(ns("new_no_expiration"), "No Expiration"))
        ),
        fluidRow(
          selectInput(ns("new_inactivity_delay"),
                      label = "Inactivity Delay",
                      selected = 15,
                      choices = c("5 min" = 5,
                                  "15 min" = 15,
                                  "30 min" = 30,
                                  "1 h" = 60,
                                  "2 h" = 120,
                                  "4 h" = 240,
                                  "8 h" = 480,
                                  "12 h" = 720)),
        ),
        fluidRow(passwordInput(ns("new_user_password"), "Enter Password")),
        fluidRow(passwordInput(ns("new_user_repeat_password"), "Repeat Password")),
        fluidRow(actionButton(ns("new_user_create"), "Create User"))
      )
    )
  )
  #  )
}
# * ------ Super-Admin UI ----------------------------------------
#' Menu de configuration disponible aux super_admin et dev
#'
#' @param id ID du module
#'
#' @importFrom shiny NS tagList h3 selectInput actionButton
#'
#' @returns UI pour configuration de super_admin
#' @export
#'
#' @examples
#' if(interactive()){
#' mod_config_ui3(id)
#' }
mod_config_ui3 <- function(id) {
  ns <- NS(id)
  tagList(
    h3("super_admin"),
    selectInput(ns("super_admin_select_user"), "Select a User", choices = NULL),
    selectInput(ns("super_admin_select_role"), "User rôle", selected = NULL, choices = c("user", "admin")),
    actionButton(ns("save_super_admin"), "Save user role")
  )
}

# * ------ DEV UI ----------------------------------------
#' Menu de configuration disponible aux dev
#'
#' @param id ID du module
#'
#' @importFrom shiny NS tagList navbarMenu navbarPage tabPanel h3 h4 h5 hr fluidRow column
#' @importFrom shiny selectInput numericInput actionButton
#' @importFrom shiny verbatimTextOutput textOutput
#' @importFrom shinyjs runjs
#'
#' @returns UI pour configuration accessible au dev
#' @export
#'
#' @examples
#' if(interactive()){
#' mod_config_ui4(id)
#' }
mod_config_ui4 <- function(id) {
  ns <- NS(id)
  tagList(
    navbarPage(
      "Dev menu:",
      tabPanel("DEV access",
               h3("contrôler les accès à DEV"),
               selectInput(ns("dev_select_user"), "Select a User", choices = NULL),
               selectInput(ns("dev_select_role"), "User rôle",
                           selected = NULL, choices = c("user", "admin", "super_admin", "dev", "public")),
               actionButton(ns("save_dev"), "Save user role")),
      navbarMenu(
        "utilité DEV",
        tabPanel(
          "test de cookie",
          h3("projet en cours"),
          verbatimTextOutput(ns("activity_and_refresh")),
          tags$hr(),
          h3("Fingerprint"),
          h5("Fingerprint au login"),
          verbatimTextOutput(ns("fingerprint_login")),
          h5("Fingerprint actuel: live"),
          actionButton(ns("read_fingerprint"), "Read Fingerprint"),
          verbatimTextOutput(ns("fingerprint")),
          tags$hr(),
          actionButton(ns("test"), "test de cookie"),
          textOutput(ns("cookie_name")),
          fluidRow(
            actionButton(ns("delete_cookie"), "Effacer le cookie"),
            actionButton(ns("write_cookie"), "Écrire un cookie, valeur = token de cette session"),
            actionButton(ns("write_cookie_diff"), "Écrire un cookie, valeur = token différent")
          ),

          fluidRow(
            column(3, numericInput(ns("cookie_expiration"), "expiration",
                                   min = 1, max = 60, value = 30)),
            column(3, selectInput(ns("expiration_unit"), "Unité",
                                  choices = c("sec" = 1, "min" = 60)))
          ),

          verbatimTextOutput(ns("cookie_value")),
          h4("Cookie validator: fichier enregistré sur S3"),
          actionButton(ns("check_cookie_validator"), "Check cookie validator"),
          fluidRow(selectInput(ns("token_selection"), "choisir un token", choices = NULL)),
          fluidRow(actionButton(ns("delete_selected_cookie_validator"), "Delete selected cookie validator")),
          verbatimTextOutput(ns("cookie_validator")),
          hr(),
          h4("Lecture des sessions actives"),
          fluidRow(actionButton(ns("read"), "Read env")),
          fluidRow(actionButton(ns("reset"), "Reset all users", class = "btn btn-danger")),
          fluidRow(verbatimTextOutput(ns("out")))
        ),
        tabPanel(
          "All input from config", value = "all_input_config",
          h3("Welcome to the Main Page!"),
          print("all input"),
          verbatimTextOutput(ns("all_input_config"))
        ),
        tabPanel(
          "Session_config", value = "session_config",
          h3("variable 'session'"),
          verbatimTextOutput(ns("main_session"))
        )
      )
    )
  )
}



# SERVER ---------------------------------------------------------------------
utils::globalVariables(c(
  "username", "userID", "role", "active", "inactivity_delay", "expire_date", "token_value"
))
#' Section serveur servant du différents UI de configuration
#'
#' @param id ID du module
#' @param sessions variable globale contenant les infos de toutes les sessions actives
#' @param input_main_app Variable INPUT de la session shiny (inclus tous les inputs)
#' @param main_session Variable de la session shiny (plusieurs données commune)
#'
#' @importFrom shiny moduleServer observeEvent showNotification reactive eventReactive renderPrint
#' @importFrom shiny updateTextInput updateSelectInput updateCheckboxInput updateDateInput reactiveVal
#' @importFrom cookies get_cookie
#' @importFrom s3db s3readRDS_HL s3saveRDS_HL s3delete_HL
#' @importFrom sodium password_verify
#' @importFrom dplyr arrange select
#' @importFrom uuid UUIDgenerate
#' @importFrom hms as_hms
#' @importFrom lubridate NA_Date_
#' @importFrom digest digest
#'
#' @returns Retourne les calculs nécessaire aux différents UI de configuration
#' @export
#'
#' @examples
#' if(interactive()) {
#' mod_config_server(id,input_main_app,main_session)
#' }
mod_config_server <- function(id,
                              sessions,
                              input_main_app,
                              main_session) {

  moduleServer(id, function(input, output, session) {

    ns <- session$ns
    config_s3_location <- session$userData$config_s3_location
    print(str_c("à partir de protegR2_mod_config_server: ", config_s3_location))

    # * ------ My account server ---------------------------------------------------------------
    observeEvent(input$save_password, {
      print("observeEvent(input$save_password, ....")
      current_cookie <- get_cookie(session$userData$config_global$cookie_name)
      print(session$userData$config_global$cookie_name)
      print(str_c("from user config (current_cookie): ", current_cookie))
      print(str_c("from user config (config_s3_location)", config_s3_location))
      cookie_validator <- s3readRDS_HL(paste0("session/", current_cookie, ".rds"))
      print(str_c("from user config (cookie_validator)", cookie_validator))

      # Vérification du mot de passe précédent
      if (!password_verify(cookie_validator[1, "hash_password"][[1]], input$previous_password)) {
        showNotification("Mot de passe actuel incorrect.", type = "error")
        return(NULL)
      }

      if (!protegR2_fct_validate_password(input$password1, input$password2)) return(NULL)

      print("avant changement de password")
      print(str_c("username: ", session$userData$user_info$valid_user()$username))

      protegR2_fct_change_pwd(username = session$userData$user_info$valid_user()$username,
                             new_hash = password_store(input$password1),
                             config_s3_location = config_s3_location)
      print("après changement de password")

      # Réinitialisation des champs avec map
      password_ids <- c("password1", "password2", "previous_password")
      map(password_ids, ~ updateTextInput(session, inputId = .x, value = ""))

      cookie_set_user(input = input, session = session)
    })


    # * ------ Admin server ---------------------------------------------------------

    all_users <- eventReactive(input$admin_menu, {
      #      input$admin_menu
      s3readRDS_HL("config_files/users_auth.rds") %>%
        arrange(username)
    })

    selected_user <- reactive({
      all_users() %>%
        filter(username == input$select_user)
    })

    output$all_users <- renderPrint({
      all_users() %>% select(-c(userID, hash_password))
    })

    # Mise à jour du selectInput lorsque les données sont disponibles
    observeEvent(input$admin_menu, {
      updateSelectInput(session, "select_user", choices = all_users() %>% filter(role == "user") %>% pull(username))
    })


    observeEvent(input$select_user, {
      user <- selected_user()
      req(nrow(user) == 1)

      updateCheckboxInput(session, "user_enable", value = as.logical(user$active))
      updateDateInput(session, "user_expiration", value = user$expire_date)
      updateCheckboxInput(session, "no_expiration", value = is.na(user$expire_date))
      updateSelectInput(session, "inactivity_delay", selected = user$inactivity_delay)
    })


    observeEvent(input$user_info_save, {
      req(all_users)

      # Un utilisateur doit avoir été sélectionné
      if (!(input$select_user %in% (all_users() %>% filter(role == "user") %>% pull(username)))) {
        showNotification("Vous devez sélectionner un utilisateur", type = "error")
        return(NULL)
      }

      # db des utilisateurs
      user_auth_db <- s3readRDS_HL("config_files/users_auth.rds")

      # tibble avec seulement l'utilisateur sélectionné par l'admin
      user_auth_updated <- user_auth_db %>%
        mutate(
          inactivity_delay = if_else(
            username == input$select_user,
            as.double(input$inactivity_delay),
            inactivity_delay  # garder la valeur existante
          ),
          expire_date = if_else(
            username == input$select_user,
            if (isTRUE(input$no_expiration)) NA_Date_ else as.Date(input$user_expiration),
            expire_date
          ),
          active = if_else(
            username == input$select_user,
            as.logical(input$user_enable),
            active  # garder la valeur existante
          )
        )

      s3saveRDS_HL(user_auth_updated,
                object_name = "config_files/users_auth.rds")

      # Notification de succès
      showNotification("informations modifiées avec succès.", type = "message")
    })



    observeEvent(input$save_password2, {
      req(all_users)

      # Un utilisateur doit avoir été sélectionné
      if (!(input$select_user %in% (all_users() %>% filter(role == "user") %>% pull(username)))) {
        showNotification("Vous devez sélectionner un utilisateur", type = "error")
        return(NULL)
      }

      if (!protegR2_fct_validate_password(input$password3, input$password4)) return(NULL)

      protegR2_fct_change_pwd(username = selected_user() %>% pull(username),
                             new_hash = password_store(input$password3),
                             config_s3_location)


      cookie_validator_delete(input$select_user, session)

      # Réinitialisation des champs avec map
      password_ids <- c("password3", "password4", "previous_password")
      map(password_ids, ~ updateTextInput(session, inputId = .x, value = ""))
    })

    observeEvent(input$new_user_create, {

      user_auth_db <- s3readRDS_HL("config_files/users_auth.rds")

      # Vérification si le username existe déjà
      if (input$new_user %in% user_auth_db$username) {
        showNotification("Ce username est déjà utilisé", type = "warning")
        return(NULL)
      }

      if ((length(input$new_user_expiration) == 0) & (input$new_no_expiration == FALSE)) {
        showNotification("Vous devez entrer une date d'expiration ou bien cocher 'no expiration'",
                         type = "warning")
        return(NULL)
      }

      # Vérification de la longueur du nouveau username
      if (nchar(input$new_user) < 5) {
        showNotification("Le username doit contenir au moins 5 caractères.", type = "warning")
        return(NULL)
      }

      if (!protegR2_fct_validate_password(input$new_user_password, input$new_user_repeat_password)) return(NULL)

      if (input$new_user_password != input$new_user_repeat_password) {
        showNotification("Les deux nouveaux mots de passe ne correspondent pas.", type = "error")
        return(NULL)
      }

      if (nchar(input$new_user_password) < 5) {
        showNotification("Le mot de passe doit contenir au moins 5 caractères.", type = "warning")
        return(NULL)
      }

      user_auth_updated <- user_auth_db %>%
        tibble::add_row(
          userID = max(user_auth_db$userID) + 1,
          username = input$new_user,
          hash_password = password_store(input$new_user_password),
          role = "user",
          created_by = session$userData$user_info$username,
          inactivity_delay = as.double(input$new_inactivity_delay),
          active = TRUE,
          expire_date = if (input$new_no_expiration) {
            as.Date(NA)
          } else {
            as.Date(input$new_user_expiration)
          }
        )

      s3saveRDS_HL(user_auth_updated,
                   object_name = "config_files/users_auth.rds")
      # Notification de succès
      showNotification("Nouvel utilisateur ajouté avec succès.", type = "message")

      updateTextInput(session, "new_user", value = "")
      updateSelectInput(session, "new_inactivity_delay", selected = 15)
      updateDateInput(session, inputId = "new_user_expiration", value = today() + 7)
      updateCheckboxInput(session, "new_no_expiration", value = FALSE)
      password_ids <- c("new_user", "new_user_password", "new_user_repeat_password")
      map(password_ids, ~ updateTextInput(session, inputId = .x, value = ""))
    })

    # * ------ Super-Admin server ---------------------------------------------------------

    observeEvent(input$admin_menu, {
      updateSelectInput(session, "super_admin_select_user",
                        choices = all_users() %>% filter(role %in% c("user", "admin")) %>% pull(username))
    })

    super_admin_selected_user <- reactive({
      s3readRDS_HL("config_files/users_auth.rds") %>%
        filter(username == input$super_admin_select_user)
    })

    observeEvent(input$super_admin_select_user, {
      updateSelectInput(session, "super_admin_select_role",
                        selected = (super_admin_selected_user() %>% pull(role)))
    })

    observeEvent(input$save_super_admin, {
      user_auth_db <- s3readRDS_HL("config_files/users_auth.rds") %>%
        mutate(role = if_else(username == input$super_admin_select_user, input$super_admin_select_role, role)) %>%

        s3saveRDS_HL(object_name = "config_files/users_auth.rds")
      # Notification de succès
      showNotification("Rôle de l'utilisateur enregistré avec succès", type = "message")
    })


    # * ------ DEV server ---------------------------------------------------------

    observeEvent(input$admin_menu, {
      updateSelectInput(session, "dev_select_user", choices = all_users() %>% pull(username))
    })

    dev_selected_user <- reactive({
      s3readRDS_HL("config_files/users_auth.rds") %>%
        filter(username == input$dev_select_user)
    })

    observeEvent(input$dev_select_user, {
      updateSelectInput(session, "dev_select_role", selected = (dev_selected_user() %>% pull(role)))
    })

    observeEvent(input$save_dev, {
      user_auth_db <- s3readRDS_HL("config_files/users_auth.rds") %>%
        mutate(role = if_else(username == input$dev_select_user, input$dev_select_role, role)) %>%
        s3saveRDS_HL(object_name = "config_files/users_auth.rds")

      showNotification("Rôle de l'utilisateur enregistré avec succès", type = "message")
    })

    output$cookie_name <- renderText(paste("Nom du cookie:", session$userData$config_global$cookie_name))

    timestamp_activity <- reactiveVal(Sys.time()) #initialisation
    observe({
      reactiveValuesToList(input)
      timestamp_activity(Sys.time())
    })

    output$activity_and_refresh <- renderPrint({
      req(timestamp_activity(),        # Vérifie la valeur réactive
          session$userData$timestamp_cookie_reset())  # Vérifie la valeur réactive

      print(paste("Dernière activité :", timestamp_activity()))
      print(paste("Dernier rafraîchissement des cookies :", session$userData$timestamp_cookie_reset()))
    })


    output$fingerprint_login <- renderPrint({
      data <- get_fingerprint(input = input_main_app)

      cat("Adresse IP: ", data$ip,
          "\nUser agent: ", data$ua,
          "\nlanguage: ", data$language,
          "\ntimestamp: ", data$timestamp,
          "\nFingerprint:", data$fingerprint)
    })

    # Lorsque l'utilisateur clique sur le bouton
    observeEvent(input$read_fingerprint, {
      req(session$clientData$url_hostname)
      fetch_client_ip(session = session,
                      ns = ns)
    })

    # Affichage des informations récupérées
    output$fingerprint <- renderPrint({
      req(input$client_ip_data)
      data <- get_fingerprint(input = input)

      cat("Lecture en direct",
          "\nAdresse IP: ", data$ip,
          "\nUser agent: ", data$ua,
          "\nlanguage: ", data$language,
          "\ntimestamp: ", data$timestamp,
          "\nFingerprint:", data$fingerprint)
    })

    ########################################################################

    observeEvent(input$delete_cookie, {
      remove_cookie(cookie_name = session$userData$config_global$cookie_name)
      print("cookie remove")
    })

    observeEvent(input$write_cookie, {
      set_cookie(cookie_name = session$userData$config_global$cookie_name,
                 cookie_value = session$userData$user_info$token_value,
                 expiration = 1 / 24 / 60 / 60 * input$cookie_expiration * as.double(input$expiration_unit))
      cat("cookie test écrit: ", as_hms(input$cookie_expiration * as.double(input$expiration_unit)), "\n")
    })

    observeEvent(input$write_cookie_diff, {
      set_cookie(cookie_name = session$userData$config_global$cookie_name,
                 cookie_value = UUIDgenerate(use.time = FALSE),
                 expiration = 1 / 24 / 60 / 60 * input$cookie_expiration * as.double(input$expiration_unit))
      cat("cookie test écrit: ", as_hms(input$cookie_expiration * as.double(input$expiration_unit)), "\n")
    })

    output$cookie_value <- renderPrint({
      valeur <- get_cookie(session$userData$config_global$cookie_name)
      valeur
    })

    observeEvent(input$delete_selected_cookie_validator, {
      s3delete_HL(object = paste0("session/", input$token_selection, ".rds"))
    })

    cookie_validators <- eventReactive(input$check_cookie_validator, {

      objets <- s3list_HL(prefix = "session/")
      fichiers <- sapply(objets, function(x) x[["Key"]])
      if (length(fichiers) > 0) {
        fichiers %>% map(s3readRDS_HL, main_folder = FALSE) %>% bind_rows()
      } else {
        NULL
      }
    })

    observeEvent(input$check_cookie_validator, {
      updateSelectInput(session, "token_selection", choices = cookie_validators()$token_value)
    })

    output$cookie_validator <- renderPrint({
      cookie_validators()
    })

    observeEvent(input$read, {
      output$out <- renderPrint({
        lapply(ls(sessions), function(tok) {
          s <- sessions[[tok]]$session   # accès à la session Shiny
          list(
            token = tok,
            user  = s$user
          )
        }) %>%
          purrr::map_dfr(~tibble(
            user        = .x$user,
            shiny_token = .x$token
          ))
      })
    })

    # Reset all users sauf l'appelant
    observeEvent(input$reset, {

      # Extraire uniquement les valid_user_df valides
      valid_users <- lapply(sessions, function(x) {
        if (!is.null(x$valid_user_df) && inherits(x$valid_user_df, "data.frame")) {
          return(x$valid_user_df)
        } else {
          return(NULL)
        }
      }) %>%
        compact() %>%
        bind_rows()

      print(valid_users)

      # effacer tous les cookies validators sauf celui de l'utilisateur qui appuie sur le bouton
      objs <- s3list_HL(prefix = "session/")
      files <- sapply(objs, function(x) x[["Key"]])
      files <- tibble(files = files) %>%
        mutate(token = sub(".*/([^/]+)\\.rds$", "\\1", files)) %>%
        filter(token != session$userData$user_info$token_value) %>%
        pull(files)

      walk(s3delete_HL,
           str_c("session/",files))

      for (tok in ls(sessions)) {
        if (tok != session$token) {
          s <- sessions[[tok]]$session
          if (!is.null(s)) {
            s$sendCustomMessage("forceReload", list())
          }
          rm(list = tok, envir = sessions)  # suppression immédiate de l'entrée
        }
      }
    })


    ########################################################################
    output$all_input_config <- renderPrint(reactiveValuesToList(input_main_app))

    output$main_session <- renderPrint(main_session)

  })
}

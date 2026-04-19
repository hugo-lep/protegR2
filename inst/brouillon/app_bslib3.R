#sidebar vide, mais qui est là au démarrage

library(shiny)
library(shinyjs)
library(bslib)

user <- 2


mon_theme <- bs_theme(
  bootswatch = "darkly",
  base_font = font_google("Roboto"),
  primary = "#3c8dbc"
)

ui <- page_sidebar(
  theme = mon_theme,
  title = tagList(
    span("Mon Dashboard bslib"),
    div(
      class = "header-icons",
      div(class = "badge-wrapper",
          actionButton("toggle_msg", icon("envelope"), class = "header-btn"),
          tags$span(class = "badge", "1")
      ),
      div(class = "badge-wrapper",
          actionButton("toggle_notif", icon("bell"), class = "header-btn"),
          tags$span(class = "badge", "2")
      )
    )

  ),
  sidebar = uiOutput("sidebar"),

#    div(
#    class = "custom-sidebar",
#
#    actionButton("accueil", tagList(icon("house"), "Accueil"), class = "sidebar-btn"),
#
#    actionButton("toggle_stats", tagList(icon("chart-line"), "Statistiques ▼"), class = "sidebar-btn"),
#    uiOutput("submenu_stats"),
#
#    actionButton("params", tagList(icon("gear"), "Paramètres"), class = "sidebar-btn")
#  ),


  mainPanel(
    uiOutput("content")
  ),
  absolutePanel(id = "msg_panel", top = 50, right = 80, width = 250, draggable = FALSE, style = "display: none;", class = "dropdown-panel",
                h5("📬 Nouveau message"),
                p(strong("De:"), " Admin"),
                p("Bienvenue dans ce dashboard bslib !")
  ),
  absolutePanel(id = "notif_panel", top = 50, right = 30, width = 250, draggable = FALSE, style = "display: none;", class = "dropdown-panel",
                h5("🔔 Notifications"),
                tags$ul(
                  tags$li("Mise à jour système prévue demain."),
                  tags$li(HTML(
                    'Nouvelle analyse disponible : <a href="#" onclick="Shiny.setInputValue(\'histogramme\', Math.random())">voir page Histogramme</a>.'
                  ))
                )
  )

)

server <- function(input, output, session) {
  stats_visible <- reactiveVal(FALSE)
  active_tab <- reactiveVal("accueil")

  observeEvent(input$toggle_stats, {
    stats_visible(!stats_visible())
  })

  output$submenu_stats <- renderUI({
    if (!stats_visible()) return(NULL)

    items <- list(
      actionButton("histogramme", "   📊 Histogramme", class = "sub-btn")
    )

    if (utilisateur() == 1) {
      items <- append(items, list(
        actionButton("resume", "   📈 Résumé", class = "sub-btn")
      ))
    }

    do.call(tagList, items)
  })

  observeEvent(input$accueil, active_tab("accueil"))
  observeEvent(input$histogramme, active_tab("histogramme"))
  observeEvent(input$resume, active_tab("resume"))
  observeEvent(input$params, active_tab("params"))

  utilisateur <- reactiveVal(NULL)
  observeEvent(input$login_user1, utilisateur(1))
  observeEvent(input$login_user2, utilisateur(2))

  output$sidebar <- renderUI({
    if (is.null(utilisateur())) return(NULL)

    div(class = "custom-sidebar",
        actionButton("accueil", tagList(icon("house"), "Accueil"), class = "sidebar-btn"),
        actionButton("toggle_stats", tagList(icon("chart-line"), "Statistiques ▼"), class = "sidebar-btn"),
        uiOutput("submenu_stats"),
        actionButton("params", tagList(icon("gear"), "Paramètres"), class = "sidebar-btn")
    )
  })



  output$content <- renderUI({
    if (is.null(utilisateur())) {
      tagList(
        h2("Connexion"),
        p("Choisissez votre profil :"),
        actionButton("login_user1", "Utilisateur 1", class = "btn-primary"),
        actionButton("login_user2", "Utilisateur 2", class = "btn-secondary")
      )
    } else {
      switch(active_tab(),
             "accueil" = tagList(h2("Bienvenue"), p("Voici la page d'accueil.")),
             "histogramme" = tagList(h2("Histogramme"), plotOutput("mon_plot")),
             "resume" = tagList(h2("Résumé"), verbatimTextOutput("resume_data")),
             "params" = tagList(h2("Paramètres"), checkboxInput("opt", "Option activée", TRUE))
      )
    }
  })

  output$mon_plot <- renderPlot({
    hist(rnorm(100), col = "#3498db", main = "Histogramme")
  })

  output$resume_data <- renderPrint({
    summary(rnorm(100))
  })

  msg_visible <- reactiveVal(FALSE)
  notif_visible <- reactiveVal(FALSE)

  observeEvent(input$toggle_msg, {
    msg_visible(!msg_visible())
    notif_visible(FALSE)
    shinyjs::toggle(id = "msg_panel", condition = msg_visible())
    shinyjs::hide(id = "notif_panel")
  })

  observeEvent(input$toggle_notif, {
    notif_visible(!notif_visible())
    msg_visible(FALSE)
    shinyjs::toggle(id = "notif_panel", condition = notif_visible())
    shinyjs::hide(id = "msg_panel")
  })

}

css <- "
.custom-sidebar {
  background-color: #222d32;
  padding: 15px;
  height: 100%;
}
.sidebar-btn {
  width: 100%;
  margin-bottom: 10px;
  text-align: left;
  color: white;
  background-color: #3c8dbc;
  border: none;
}
.sidebar-btn:hover {
  background-color: #367fa9;
}
.sub-btn {
  width: 100%;
  margin: 5px 0;
  background-color: #1e282c;
  color: white;
  border: none;
  text-align: left;
}
.sub-btn:hover {
  background-color: #2c3b41;
}
.badge {
  background-color: red;
  color: white;
  border-radius: 50%;
  padding: 3px 7px;
  font-size: 12px;
  margin-left: -10px;
  margin-top: -10px;
}
.header-btn {
  background: none;
  border: none;
  color: white;
  font-size: 18px;
  margin-left: 10px;
}
.badge {
  background-color: red;
  color: white;
  border-radius: 50%;
  padding: 2px 6px;
  font-size: 11px;
  position: absolute;
  animation: pulse 1.2s infinite ease-in-out;

}
.dropdown-panel {
  background-color: #1e282c;
  color: white;
  padding: 15px;
  border-radius: 5px;
  box-shadow: 2px 2px 6px rgba(0,0,0,0.5);
  z-index: 999;
}
.header-icons {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-left: auto;
}
.badge-wrapper {
  position: relative;
}
/* Style pour le badge */
.badge {
  position: absolute;
  top: 2px;
  right: -5px;
  background-color: red;
  color: white;
  border-radius: 50%;
  padding: 2px 5px;
  font-size: 11px;
  line-height: 1;
  animation: pulse 1.2s infinite ease-in-out;
}

/* Définition de l’animation */
@keyframes pulse {
  0%   { transform: scale(1); opacity: 1; }
  50%  { transform: scale(1.2); opacity: 0.85; }
  100% { transform: scale(1); opacity: 1; }
}
"

ui <- tagList(
  tags$head(tags$style(HTML(css))),
  ui
)

shinyApp(ui = tagList(useShinyjs(), tags$head(tags$style(HTML(css))), ui),
         server = server)

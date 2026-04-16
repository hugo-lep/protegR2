library(shiny)
library(shinyjs)
library(bslib)

user <- 2

mon_theme <- bs_theme(
  bootswatch = "darkly",
  base_font  = font_google("Roboto"),
  primary    = "#3c8dbc"
)

css <- "
/* Badges sur les icônes */
.badge-wrapper {
  position: relative;
  display: inline-block;
}
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
@keyframes pulse {
  0%   { transform: scale(1);   opacity: 1;    }
  50%  { transform: scale(1.2); opacity: 0.85; }
  100% { transform: scale(1);   opacity: 1;    }
}

/* Panneaux flottants (messages / notifications) */
.dropdown-panel {
  background-color: #1e282c;
  color: white;
  padding: 15px;
  border-radius: 5px;
  box-shadow: 2px 2px 6px rgba(0,0,0,0.5);
  z-index: 999;
}
"

# ── Icônes avec badges dans le titre ─────────────────────────────────────────
titre <- tagList(
  span("Mon Dashboard bslib"),
  div(
    style = "margin-left: auto; display: flex; align-items: center; gap: 10px;",
    div(class = "badge-wrapper",
        actionButton("toggle_msg",   icon("envelope"), class = "btn-link text-white p-0"),
        tags$span(class = "badge", "1")
    ),
    div(class = "badge-wrapper",
        actionButton("toggle_notif", icon("bell"),     class = "btn-link text-white p-0"),
        tags$span(class = "badge", "2")
    )
  )
)

# ── Sous-menu Statistiques ────────────────────────────────────────────────────
# nav_panel() sans contenu dans la sidebar = juste un item de navigation.
# Le contenu est défini une seule fois dans navset_pill_list() du corps.
stats_panels <- list(
  nav_panel("Histogramme", icon = icon("chart-bar"),
    card(
      card_header("Histogramme"),
      card_body(plotOutput("mon_plot"))
    )
  )
)

# Item conditionnel selon le rôle
if (user == 1) {
  stats_panels <- c(stats_panels, list(
    nav_panel("Résumé", icon = icon("chart-line"),
      card(
        card_header("Résumé"),
        card_body(verbatimTextOutput("resume_data"))
      )
    )
  ))
}

# ── UI ───────────────────────────────────────────────────────────────────────
ui <- tagList(
  useShinyjs(),
  tags$head(tags$style(HTML(css))),

  page_sidebar(
    theme = mon_theme,
    title = titre,

    # ── Sidebar : navset_pill_list gère la navigation ─────────────────────
    sidebar = sidebar(
      width = 220,

      do.call(
        navset_pill_list,
        c(
          list(id = "nav_principale", well = FALSE),

          list(
            nav_panel("Accueil", icon = icon("house"),
              # contenu de la page Accueil
              card(
                card_header("Bienvenue"),
                card_body(p("Voici la page d'accueil."))
              )
            ),

            nav_menu("Statistiques", icon = icon("chart-line"),
              !!!stats_panels        # injection des panels conditionnels
            ),

            nav_panel("Paramètres", icon = icon("gear"),
              card(
                card_header("Paramètres"),
                card_body(checkboxInput("opt", "Option activée", TRUE))
              )
            )
          )
        )
      )
    ),

    # ── Corps : navset_pill_list() synchronisé avec la sidebar ────────────
    # On utilise le même id "nav_principale" → bslib synchronise les deux.
    do.call(
      navset_pill_list,
      c(
        list(id = "nav_principale"),

        list(
          nav_panel("Accueil",
            card(
              card_header("Bienvenue"),
              card_body(p("Voici la page d'accueil."))
            )
          ),

          nav_menu("Statistiques",
            !!!stats_panels
          ),

          nav_panel("Paramètres",
            card(
              card_header("Paramètres"),
              card_body(checkboxInput("opt", "Option activée", TRUE))
            )
          )
        )
      )
    ),

    # ── Panneaux flottants ────────────────────────────────────────────────
    absolutePanel(
      id = "msg_panel", top = 50, right = 80, width = 250,
      style = "display: none;", class = "dropdown-panel",
      h5("Nouveau message"),
      p(strong("De :"), " Admin"),
      p("Bienvenue dans ce dashboard bslib !")
    ),
    absolutePanel(
      id = "notif_panel", top = 50, right = 30, width = 250,
      style = "display: none;", class = "dropdown-panel",
      h5("Notifications"),
      tags$ul(
        tags$li("Mise à jour système prévue demain."),
        tags$li("Nouvelle analyse disponible.")
      )
    )
  )
)

# ── Server ───────────────────────────────────────────────────────────────────
server <- function(input, output, session) {

  # Graphiques
  output$mon_plot <- renderPlot({
    hist(rnorm(100), col = "#3498db", main = "Histogramme", border = "white")
  })

  output$resume_data <- renderPrint({
    summary(rnorm(100))
  })

  # Panneaux flottants
  msg_visible   <- reactiveVal(FALSE)
  notif_visible <- reactiveVal(FALSE)

  observeEvent(input$toggle_msg, {
    msg_visible(!msg_visible())
    notif_visible(FALSE)
    shinyjs::toggle(id = "msg_panel",   condition = msg_visible())
    shinyjs::hide(id  = "notif_panel")
  })

  observeEvent(input$toggle_notif, {
    notif_visible(!notif_visible())
    msg_visible(FALSE)
    shinyjs::toggle(id = "notif_panel", condition = notif_visible())
    shinyjs::hide(id  = "msg_panel")
  })
}

shinyApp(ui, server)

#' @title module demo de protegR2, servant à présenter la structure
#'
#' @param id ID du module
#' @param tr Fonction de traduction retournée par make_tr()
#'
#' @importFrom shiny NS tagList h3
#' @importFrom shiny textInput textOutput
#'
#' @returns UI demo
#' @export
#'
#' @examples
#' if(interactive()){
#' mod_demo1_ui("demo1")
#' }
mod_demo1_ui <- function(id, tr) {
  ns <- NS(id)
  tagList(
    h3(tr("contenu_du_module")),
    textInput(ns("txt"), "Écris quelque chose"),
    textOutput(ns("result"))
  )
}

#' @title module demo de protegR2, servant à présenter la structure, section serveur
#'
#' @param id ID du module
#'
#' @importFrom shiny moduleServer renderText
#'
#' @returns Calcul nécessaire au UI
#' @export
#'
#' @examples
#' if(interactive()){
#' mod_demo1_server("demo1")
#' }
mod_demo1_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    output$result <- renderText({
      paste("Tu as écrit :", input$txt)
    })
  })
}

#' @title module demo de protegR2, servant à présenter la structure + détail du role
#'
#' @description
#' Particularité de ce module, en fait il ne s'agit que d'un fonction, car il n'y avait pas
#' de besoin au niveau du serveur
#'
#'
#' @param id ID du module
#' @param session variable shiny avec info nécessaire au module
#'
#' @returns UI demo
#' @export
#'
#' @examples
#' if(interactive()){
#' mod_demo2_ui("demo2",session)
#' }
mod_demo2_ui <- function(id, session) {

  tagList(
    h3("Contenu Menu 1"),
    message <- switch(
      session$userData$user_info$user_role(),
      "user"  = "👤 Bienvenue Utilisateur. Accès standard.",
      "admin" = "👑 Bienvenue Admin ! Tu peux ajouter des utilisateurs.",
      "super-admin" = "Bienvenue Super-admin ! Tu peux créer des utilisateurs, mais aussi leur donner des accès admin",
      "dev" = "Bienvenue DEV ! Fais attention, tes accès pourraient briser quelque chose",
      "🤖 Rôle inconnu."
    )
  )
}


#' @title Dummy module pour tester les subitems (section ui)
#'
#' @param id du module
#'
#' @importFrom shiny NS tagList h3 sliderInput plotOutput
#'
#' @returns Un UI très simple
#' @export
#'
#' @examples
#' if(interactive()){
#' mod_demo_subitem1(id)
#' }
mod_demo_subitem1_ui <- function(id) {
  ns <- NS(id)
  tagList(
    h3("mod_demo_subitem1"),
    sliderInput(ns("n"), "Nombre d'observations", 10, 100, 50),
    plotOutput(ns("hist"))
  )
}

#' @title Dummy module pour tester les subitems (section ui)
#'
#' @param id ID du module
#'
#' @importFrom shiny moduleServer renderPlot
#' @importFrom graphics hist
#' @importFrom stats rnorm
#'
#' @returns Calcul nécessaire au UI
#' @export
#'
#' @examples
#' if(interactive()){
#' mod_demo_subitem1_server(id)
#' }
mod_demo_subitem1_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    output$hist <- renderPlot({
      hist(rnorm(input$n), main = "Histogramme", col = "steelblue")
    })
  })
}





#' @title Dummy module pour tester les subitems
#'
#' @param id du module (ne serait pas nécessaire par il n'y a pas de section serveur au module)
#'
#' @importFrom shiny NS tagList h3
#'
#' @returns Un UI très simple
#' @export
#'
#' @examples
#' if(interactive()){
#' mod_demo_subitem2(id)
#' }
mod_demo_subitem2 <- function(id) {

  tagList(
    h3("mod_demo_subitem2")
  )
}

#' Module démo pour illustrer page_fillable — section UI
#'
#' @description
#' Démontre la capacité de page_fillable() à étirer le contenu pour occuper
#' toute la hauteur disponible du viewport, sans scrollbar.
#'
#' Architecture :
#'   card(fill = TRUE)       → la card s'étire pour remplir la hauteur
#'   full_screen = TRUE      → bouton pour passer en plein écran (bslib)
#'   plotOutput(fill = TRUE) → le graphique remplit la card
#'
#' Ce comportement n'est visible qu'avec page_fillable() comme conteneur.
#' Dans page_fluid() ou page_fixed(), le contenu conserve sa hauteur naturelle.
#'
#' @param id ID du module
#'
#' @importFrom shiny NS sliderInput plotOutput
#' @importFrom bslib card card_header
#'
#' @returns UI du module démo fillable
#' @export
#'
#' @examples
#' if (interactive()) {
#'   mod_fillable_ui("fillable_demo")
#' }
mod_fillable_ui <- function(id) {
  ns <- NS(id)

  # card() de bslib est le composant naturel pour les layouts fillable.
  # fill = TRUE      : la card s'étire verticalement pour occuper
  #                    tout l'espace que page_fillable() lui alloue.
  # full_screen = TRUE : ajoute un bouton en haut à droite pour passer
  #                    la card en plein écran (fonctionnalité bslib native).
  # plotOutput(fill = TRUE) : le graphique remplit la card — sans ça,
  #                    le plot aurait une hauteur fixe (400px par défaut)
  #                    et la card ne s'étirerait pas visuellement.
  card(
    fill        = TRUE,
    full_screen = TRUE,
    card_header(
      tagList(icon("chart-line"), " Démo page_fillable — graphique plein écran")
    ),
    sliderInput(ns("n"), "Nombre de points", min = 50, max = 500, value = 200),
    plotOutput(ns("plot"), fill = TRUE)
  )
}

#' Module démo pour illustrer page_fillable — section serveur
#'
#' @param id ID du module
#'
#' @importFrom shiny moduleServer renderPlot
#' @importFrom stats rnorm
#'
#' @returns Calculs nécessaires au UI
#' @export
#'
#' @examples
#' if (interactive()) {
#'   mod_fillable_server("fillable_demo")
#' }
mod_fillable_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    output$plot <- renderPlot({
      x <- rnorm(input$n)
      y <- rnorm(input$n)
      plot(
        x, y,
        col  = "steelblue",
        pch  = 19,
        cex  = 0.7,
        main = paste("Nuage de", input$n, "points — le graphique remplit la hauteur disponible"),
        xlab = "x",
        ylab = "y"
      )
    })
  })
}


#' Module démo pour illustrer page_sidebar — filtres (section UI sidebar)
#'
#' @description
#' Démontre l'utilisation typique de page_sidebar() : filtres à gauche dans
#' le sidebar, résultat réactif à droite dans la zone principale.
#'
#' Ce module est divisé en deux fonctions UI (même id) + un serveur :
#'   mod_demo_sidebar_filter_ui()  → placé dans sidebar()
#'   mod_demo_sidebar_content_ui() → placé dans la zone principale
#'   mod_demo_sidebar_server()     → relie les deux via le même id
#'
#' Si le programmeur veut des onglets dans la zone principale, il les place
#' directement dans mod_demo_sidebar_content_ui() — pas dans le template.
#'
#' @param id ID du module
#'
#' @importFrom shiny NS tagList sliderInput selectInput hr h5
#'
#' @returns UI des filtres pour le sidebar
#' @export
#'
#' @examples
#' if (interactive()) {
#'   mod_demo_sidebar_filter_ui("sidebar_demo")
#' }
mod_demo_sidebar_filter_ui <- function(id) {
  ns <- NS(id)

  tagList(
    h5("Filtres"),
    hr(),
    sliderInput(ns("n"),
                label = "Nombre de points",
                min   = 10,
                max   = 300,
                value = 100),
    selectInput(ns("couleur"),
                label   = "Couleur",
                choices = c("Bleu"    = "steelblue",
                            "Rouge"   = "firebrick",
                            "Vert"    = "seagreen"),
                selected = "steelblue")
  )
}


#' Module démo pour illustrer page_sidebar — contenu (section UI principale)
#'
#' @description
#' Zone principale du module démo sidebar. Reçoit les résultats calculés
#' par le serveur à partir des filtres définis dans mod_demo_sidebar_filter_ui().
#'
#' @param id ID du module (doit être identique à mod_demo_sidebar_filter_ui)
#'
#' @importFrom shiny NS plotOutput
#'
#' @returns UI de la zone principale
#' @export
#'
#' @examples
#' if (interactive()) {
#'   mod_demo_sidebar_content_ui("sidebar_demo")
#' }
mod_demo_sidebar_content_ui <- function(id) {
  ns <- NS(id)

  plotOutput(ns("plot"), height = "500px")
}


#' Module démo pour illustrer page_sidebar — serveur
#'
#' @description
#' Relie les filtres (sidebar) au contenu (zone principale).
#' Le graphique se met à jour automatiquement quand l'utilisateur
#' modifie les filtres — c'est la réactivité Shiny standard.
#'
#' @param id ID du module
#'
#' @importFrom shiny moduleServer renderPlot
#' @importFrom stats rnorm
#'
#' @returns Calculs nécessaires au UI
#' @export
#'
#' @examples
#' if (interactive()) {
#'   mod_demo_sidebar_server("sidebar_demo")
#' }
mod_demo_sidebar_server <- function(id) {
  moduleServer(id, function(input, output, session) {

    output$plot <- renderPlot({
      x <- rnorm(input$n)
      y <- rnorm(input$n)
      plot(
        x, y,
        col  = input$couleur,
        pch  = 19,
        cex  = 0.8,
        main = paste("Nuage de", input$n, "points"),
        xlab = "x",
        ylab = "y"
      )
    })

  })
}


#' Module démo pour faire tourner un avion section ui
#'
#' @description
#' Une particularité de ce module est qu'il utilise du java script.
#' Ce qui fait que c'est le navigateur de l'utilisateur qui fait tourner l'image
#' Ce qui évite de multiplier les calculs si jamais il y a beaucoup d'utilisateur
#'
#' @param id ID du module
#'
#' @importFrom shiny NS sliderInput img
#'
#' @returns UI pour le module démo
#' @export
#'
#' @examples
#' if(interactive()){
#' mod_demo_airplane_ui(id)
#' }
mod_demo_airplane_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Charger le JS externe
    tags$head(
      tags$script(src = "static/airplane_rotation.js")
    ),
    img(
      src = "static/plane-black.png",
      id = ns("plane"),
      width = "100px"
    ),
    sliderInput(ns("angle"), "Angle de rotation", min = 0, max = 360, value = 0)
  )
}

#' Module démo pour faire tourner un avion section serveur
#'
#' @param id ID du module
#'
#' @importFrom shiny moduleServer addResourcePath observe
#'
#' @returns fournit les calculs pour le module ui
#' @export
#'
#' @examples
#' if(interactive()){
#' mod_demo_airplane_server(id)
#' }
mod_demo_airplane_server <- function(id) {
  moduleServer(id, function(input, output, session) {

    # Déclare les ressources du package
    addResourcePath("static", system.file("app/www", package = "protegR2"))

    observe({
      session$sendCustomMessage(
        "rotateImage",
        list(id = session$ns("plane"), angle = input$angle)
      )
    })
  })
}

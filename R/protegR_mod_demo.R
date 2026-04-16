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

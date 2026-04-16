print("server")
# server.R
server <- function(input, output, session) {
  protegR_server(input, output, session)  # variables globales accessibles
}

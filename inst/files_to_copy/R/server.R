print("server")
# server.R
server <- function(input, output, session) {

  # Si user_config_backend = "postgres" dans config_global :
  #   remplacer pool = NULL par pool = pool
  #   (pool doit être créé dans global.R via pool::dbPool())
  protegR2_server(input, output, session, pool = NULL)
}

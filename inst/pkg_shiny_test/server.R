print("server")
# server.R
server <- function(input, output, session) {
  # pool est défini dans global.R.
  # En mode "none" ou "s3", pool = NULL — ignoré silencieusement.
  # En mode "postgres", pool doit être passé ici pour que les sessions et
  # config_user soient lus/écrits dans PostgreSQL.
  protegR2_server(input, output, session, pool = pool)
}

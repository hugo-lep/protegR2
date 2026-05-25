# ══════════════════════════════════════════════════════════════════════════════
# protegR2_db_connection.R
# ══════════════════════════════════════════════════════════════════════════════
#
# Fonction utilitaire pour créer le pool de connexion PostgreSQL à partir
# de config_global. Remplace le bloc pool::dbPool(...) répétitif dans global.R.
# ══════════════════════════════════════════════════════════════════════════════


#' Créer un pool de connexion PostgreSQL depuis config_global
#'
#' @description
#' Lit les credentials dans `config_global$protegR2$db` et crée un pool de
#' connexions via `pool::dbPool()`. À appeler dans `global.R` après le
#' chargement de `config_global`.
#'
#' Remplace le bloc standard :
#' ```r
#' pool <- pool::dbPool(
#'   RPostgres::Postgres(),
#'   dbname   = config_global$protegR2$db$dbname,
#'   host     = config_global$protegR2$db$host,
#'   port     = config_global$protegR2$db$port,
#'   user     = config_global$protegR2$db$user,
#'   password = config_global$protegR2$db$password
#' )
#' ```
#'
#' Par :
#' ```r
#' pool <- protegR2_db_connection(config_global)
#' ```
#'
#' @section Fermeture propre :
#' Enregistre automatiquement `pool::poolClose(pool)` via `shiny::onStop()`
#' pour libérer les connexions à l'arrêt de l'application. Aucune action
#' manuelle requise.
#'
#' @param config_global Liste de configuration du projet. Doit contenir
#'   `$protegR2$db` avec les champs `dbname`, `host`, `port`, `user`,
#'   `password`. Généré par `s3readRDS_HL()` ou `protegR2_local_config()`.
#' @param min_size Nombre minimum de connexions maintenues en permanence.
#'   Défaut `2`.
#' @param max_size Nombre maximum de connexions simultanées. Défaut `10`.
#'
#' @return Un objet pool (`pool::Pool`).
#'
#' @importFrom rlang %||%
#'
#' @export
protegR2_db_connection <- function(config_global, min_size = 2, max_size = 10) {

  # ── Validation ─────────────────────────────────────────────────────────────
  db <- config_global$protegR2$db

  if (is.null(db)) {
    stop(
      "[protegR2] config_global$protegR2$db est NULL.\n",
      "  Ajouter les credentials dans config_global (voir inst/dev/01_protegR2_start.R).\n",
      "  Exemple :\n",
      "    config_global$protegR2$db <- list(\n",
      "      host = \"localhost\", port = 5432,\n",
      "      dbname = \"mon_app\", user = \"mon_app\", password = \"...\"\n",
      "    )"
    )
  }

  champs_requis <- c("dbname", "host", "port", "user", "password")
  manquants     <- champs_requis[!champs_requis %in% names(db)]
  if (length(manquants) > 0) {
    stop(
      "[protegR2] Champs manquants dans config_global$protegR2$db : ",
      paste(manquants, collapse = ", "), "."
    )
  }

  # ── Vérification des packages requis ──────────────────────────────────────
  # pool et RPostgres sont dans Suggests — ils ne sont requis qu'en mode postgres.
  if (!requireNamespace("pool",      quietly = TRUE)) stop("[protegR2] Package 'pool' requis. Installer avec : install.packages('pool')")
  if (!requireNamespace("RPostgres", quietly = TRUE)) stop("[protegR2] Package 'RPostgres' requis. Installer avec : install.packages('RPostgres')")

  # ── Création du pool ───────────────────────────────────────────────────────
  p <- pool::dbPool(
    drv      = RPostgres::Postgres(),
    dbname   = db$dbname,
    host     = db$host,
    port     = db$port   %||% 5432L,
    user     = db$user,
    password = db$password,
    minSize  = min_size,
    maxSize  = max_size
  )

  # ── Fermeture automatique à l'arrêt de l'app ──────────────────────────────
  # shiny::onStop() enregistre un hook exécuté quand shiny::runApp() se termine
  # (bouton Stop dans RStudio, ou arrêt du process shiny-server).
  # Sans ça, les connexions restent ouvertes jusqu'au GC ou au restart du process.
  shiny::onStop(function() {
    pool::poolClose(p)
    message("[protegR2] Pool PostgreSQL fermé.")
  })

  message("[protegR2] Pool PostgreSQL créé (", db$host, ":", db$port %||% 5432L,
          " / ", db$dbname, ")")

  p
}

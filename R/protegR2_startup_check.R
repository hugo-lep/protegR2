# ══════════════════════════════════════════════════════════════════════════════
# protegR2_startup_check.R
# ══════════════════════════════════════════════════════════════════════════════
#
# Vérification des ressources nécessaires au démarrage de l'application.
#
# À appeler dans global.R, après le chargement de config_global et du pool.
# S'adapte automatiquement au backend configuré (local / s3 / postgres).
#
# Objectif : remplacer un crash muet par un message clair guidant vers la
# solution — particulièrement utile lors de l'installation d'une nouvelle app.
# ══════════════════════════════════════════════════════════════════════════════


#' Vérifier la configuration au démarrage
#'
#' @description
#' Détecte le backend configuré et vérifie que les ressources nécessaires sont
#' accessibles (fichier d'utilisateurs, tables, pool de connexion). Affiche un
#' message diagnostique dans la console avec les actions correctives si une
#' ressource manque.
#'
#' À appeler dans `global.R`, après le chargement de `config_global` et du
#' `pool` (si postgres), mais avant `shinyApp()`.
#'
#' @param config_global Liste de configuration globale retournée par
#'   `s3readRDS_HL()` ou `protegR2_local_config()`.
#' @param pool Pool de connexion PostgreSQL créé avec `pool::dbPool()`.
#'   Ignoré si le backend n'est pas `"postgres"`. Défaut `NULL`.
#'
#' @return `invisible(NULL)`. Les messages sont émis via `message()`.
#'
#' @importFrom rlang %||%
#' @importFrom s3db s3exist_HL
#' @importFrom DBI dbExistsTable Id
#'
#' @export
protegR2_startup_check <- function(config_global, pool = NULL) {

  # ── Guard : config_global non chargé ─────────────────────────────────────
  # Si config_global est NULL ou mal formé, l'app crasherait de toute façon —
  # autant afficher un message clair ici plutôt qu'une erreur cryptique plus loin.
  # Cas typique : nouvelle installation, config_global.rds pas encore sur S3.
  if (is.null(config_global) || is.null(config_global$protegR2)) {
    message("[protegR2] ⚠  config_global est NULL ou ne contient pas $protegR2.")
    message("            Pour une nouvelle installation, suis les étapes dans :")
    message("            inst/dev/01_protegR2_start.R  (copié par protegR2_init())")
    return(invisible(NULL))
  }

  backend <- config_global$protegR2$user_config_backend %||% "none"

  # ── Helpers d'affichage ───────────────────────────────────────────────────
  #
  # .ok()   : confirmation verte — tout est en ordre
  # .warn() : avertissement — quelque chose manque, avec action corrective
  #
  # On utilise message() plutôt que warning() pour deux raisons :
  #   1. message() s'affiche toujours dans la console (pas supprimable par défaut)
  #   2. warning() peut être mis en file d'attente et s'afficher hors contexte
  #
  # Le préfixe [protegR2] rend les messages facilement repérables dans les logs.

  .ok <- function(msg) {
    message("[protegR2] ✓  ", msg)  # ✓
  }

  .warn <- function(...) {
    lines <- c(...)
    # Première ligne avec le préfixe et l'icône d'avertissement
    message("[protegR2] ⚠  ", lines[[1]])  # ⚠
    # Lignes suivantes (actions correctives) indentées
    if (length(lines) > 1) {
      for (l in lines[-1]) message("            ", l)
    }
  }

  # ── Mode local ─────────────────────────────────────────────────────────────
  #
  # En mode local, les utilisateurs sont stockés dans config_global lui-même
  # (champ $protegR2$local_users_auth), sans accès réseau.
  # Si ce champ est absent ou vide, l'app crashera au premier login.
  if (backend == "local") {

    local_users <- config_global$protegR2$local_users_auth

    if (is.null(local_users) || nrow(local_users) == 0) {
      .warn(
        "Mode local : aucun utilisateur trouvé dans config_global.",
        "config_global$protegR2$local_users_auth est NULL ou vide.",
        "",
        "Solution : dans global.R, utilise :",
        "  config_global <- protegR2_local_config()",
        "",
        "Pour des utilisateurs personnalisés :",
        "  config_global <- protegR2_local_config(",
        "    users = protegR2_build_local_users(liste_utilisateurs)",
        "  )"
      )
    } else {
      n_users <- nrow(local_users)
      .ok(paste0("Mode local — ", n_users, " utilisateur(s) chargé(s)."))
    }

  # ── Mode s3 ────────────────────────────────────────────────────────────────
  #
  # En mode s3, deux fichiers doivent exister sur le bucket :
  #   - config_files/users_auth.rds : liste des utilisateurs et leurs hashes
  #   - config_files/config_global.rds : déjà chargé (sinon on ne serait pas ici)
  #
  # Note : si s3_connection_HL() n'a pas été appelé avant, s3exist_HL() échoue
  # avec une erreur réseau — on la capture pour afficher un message utile.
  } else if (backend %in% c("s3", "none")) {

    # "none" est le mode s3 implicite (comportement original avant l'introduction
    # de user_config_backend). On le traite identiquement à "s3".

    all_ok <- TRUE

    # Vérification users_auth.rds
    users_auth_exists <- tryCatch(
      s3exist_HL(object = "config_files/users_auth.rds"),
      error = function(e) {
        .warn(
          paste0("Mode s3 : impossible de contacter S3 (", conditionMessage(e), ")."),
          "Vérifie que s3_connection_HL() est appelé dans global.R",
          "avant protegR2_startup_check()."
        )
        NA  # NA = erreur réseau, distinct de FALSE = fichier absent
      }
    )

    if (isFALSE(users_auth_exists)) {
      all_ok <- FALSE
      .warn(
        "Mode s3 : fichier 'config_files/users_auth.rds' introuvable sur S3.",
        "",
        "Solution : initialise l'ensemble du projet avec :",
        "  protegR2_setup(config_global)",
        "",
        "Pour une nouvelle installation complète (config_global non encore sur S3),",
        "suis toutes les étapes dans inst/dev/01_protegR2_start.R",
        "(copié dans ton projet par protegR2_init())."
      )
    } else if (is.na(users_auth_exists)) {
      all_ok <- FALSE  # erreur réseau, déjà affichée dans le tryCatch
    }

    if (all_ok) .ok("Mode s3 — config_global et users_auth.rds accessibles.")

  # ── Mode postgres ──────────────────────────────────────────────────────────
  #
  # En mode postgres, les sessions sont stockées en base de données, mais les
  # utilisateurs (users_auth) restent sur S3. Il faut donc vérifier les deux :
  #   - Le pool est actif et la table protegr2.sessions existe
  #   - config_files/users_auth.rds existe sur S3
  } else if (backend == "postgres") {

    all_ok <- TRUE

    # ── Vérification du pool ─────────────────────────────────────────────────
    if (is.null(pool)) {
      all_ok <- FALSE
      .warn(
        "Mode postgres : pool est NULL.",
        "",
        "Solution : dans global.R, crée le pool avant protegR2_startup_check() :",
        "  pool <- pool::dbPool(",
        "    drv      = RPostgres::Postgres(),",
        "    dbname   = config_global$protegR2$db$dbname,",
        "    host     = config_global$protegR2$db$host,",
        "    ...",
        "  )",
        "  protegR2_startup_check(config_global, pool = pool)"
      )
    } else {

      # ── Vérification de la table protegr2.sessions ───────────────────────
      # DBI::dbExistsTable() avec Id(schema, table) est le moyen portable de
      # vérifier une table dans un schéma non-public.
      sessions_check <- tryCatch({
        list(
          ok    = DBI::dbExistsTable(pool, DBI::Id(schema = "protegr2", table = "sessions")),
          error = NULL
        )
      }, error = function(e) {
        list(ok = FALSE, error = conditionMessage(e))
      })

      if (!is.null(sessions_check$error)) {
        all_ok <- FALSE
        .warn(
          paste0("Mode postgres : erreur de connexion — ", sessions_check$error),
          "",
          "Vérifie que le pool est actif et que la base est accessible.",
          "Si tu utilises un tunnel SSH, assure-toi qu'il est ouvert."
        )
      } else if (!sessions_check$ok) {
        all_ok <- FALSE
        .warn(
          "Mode postgres : table 'protegr2.sessions' introuvable.",
          "",
          "Solution : initialise le schéma et les tables avec :",
          "  protegR2_setup(config_global, pool = pool)",
          "",
          "Pour une nouvelle installation complète, suis les étapes dans",
          "inst/dev/01_protegR2_start.R  (copié par protegR2_init())."
        )
      }
    }

    # ── Vérification users_auth.rds sur S3 ──────────────────────────────────
    # Les utilisateurs sont toujours stockés sur S3, même en mode postgres.
    # Le pool gère uniquement les sessions (tokens de connexion).
    users_auth_exists <- tryCatch(
      s3exist_HL(object = "config_files/users_auth.rds"),
      error = function(e) {
        .warn(
          paste0("Mode postgres : impossible de contacter S3 (", conditionMessage(e), ")."),
          "Les utilisateurs sont sur S3 même en mode postgres.",
          "Vérifie que s3_connection_HL() est appelé dans global.R."
        )
        NA
      }
    )

    if (isFALSE(users_auth_exists)) {
      all_ok <- FALSE
      .warn(
        "Mode postgres : fichier 'config_files/users_auth.rds' introuvable sur S3.",
        "",
        "Solution : initialise l'ensemble du projet avec :",
        "  protegR2_setup(config_global, pool = pool)"
      )
    }

    if (all_ok) .ok("Mode postgres — pool actif, table sessions OK, users_auth.rds accessible.")

  } else {

    # ── Backend inconnu ────────────────────────────────────────────────────
    .warn(
      paste0("Backend inconnu : '", backend, "'."),
      "Valeurs acceptées : \"local\", \"s3\", \"postgres\".",
      "Vérifie config_global$protegR2$user_config_backend."
    )
  }

  invisible(NULL)
}

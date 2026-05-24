# ══════════════════════════════════════════════════════════════════════════════
# protegR2_local.R
# ══════════════════════════════════════════════════════════════════════════════
#
# Infrastructure pour le mode backend "local".
#
# Ce mode permet d'utiliser protegR2 sans S3 ni PostgreSQL — idéal pour
# démarrer un projet rapidement, pour des démos, ou pour pkg_shiny_test.
#
# Limitations intentionnelles (voulu, pas un bug) :
#   - Lecture seule : aucune écriture sur disque ou réseau
#   - Sessions stockées en mémoire → perdues au restart
#   - Modules de gestion des utilisateurs masqués dans l'UI
#   - Changement de mot de passe non fonctionnel
#
# Ces limitations sont cohérentes : en mode local, la source de vérité est le
# fichier R du projet (protegR2_local_users.R), pas l'interface de l'app.
#
# Entrée dans les projets : user_config_backend = "local" dans config_global.
# ══════════════════════════════════════════════════════════════════════════════


# ── Stockage des sessions locales ─────────────────────────────────────────────
#
# Environnement au niveau du package, partagé entre toutes les sessions Shiny
# du même processus R. Correctement isolé de l'environnement `sessions` du
# projet (qui trace les sessions Shiny, pas les tokens d'authentification).
#
# Structure de chaque entrée :
#   .local_sessions[[token_value]] <- list(
#     username     = "user1",
#     expiration   = Sys.time() + 1800,   # POSIXct
#     finger_print = "abc123..."
#   )
.local_sessions <- new.env(parent = emptyenv())


# ── Utilisateurs par défaut (pkg_shiny_test) ──────────────────────────────────
#
# Les 5 utilisateurs standards de protegR2, un par rôle.
# Mots de passe hachés via bcrypt (sodium::password_store) — ~1s au premier appel.
#
# user1/pass1 → role: user
# user2/pass2 → role: user  (même rôle que user1, config_user différente)
# admin/pass3 → role: admin
# super_admin/pass4 → role: super_admin
# dev/pass5   → role: dev
#
#' @importFrom sodium password_store
#' @importFrom lubridate today
#' @noRd
protegR2_local_users_default <- function() {
  data.frame(
    userID           = 1:5,
    username         = c("user1", "user2", "admin", "super_admin", "dev"),
    hash_password    = c(
      password_store("pass1"),
      password_store("pass2"),
      password_store("pass3"),
      password_store("pass4"),
      password_store("pass5")
    ),
    role             = c("user", "user", "admin", "super_admin", "dev"),
    created_by       = rep("local", 5),
    # 30 min en local : plus pratique pour les tests que les 5 min par défaut
    inactivity_delay = rep(30, 5),
    active           = TRUE,
    # dev : NA = jamais expiré. Autres : quelques jours pour démo.
    expire_date      = c(
      today() + 7,
      today() + 8,
      today() + 9,
      today() + 10,
      as.Date(NA)
    ),
    dev_access       = c(FALSE, FALSE, FALSE, FALSE, TRUE),
    stringsAsFactors = FALSE
  )
}


#' Convertir une liste d'utilisateurs (plain-text) en data.frame users_auth
#'
#' @description
#' Prend la liste retournée par `protegR2_local_users()` (défini dans le projet
#' utilisateur) et retourne un `data.frame` compatible avec la structure
#' `users_auth` attendue par protegR2, avec les mots de passe hachés en bcrypt.
#'
#' Les mots de passe en clair ne sont jamais stockés — uniquement dans le
#' fichier source `protegR2_local_users.R`, jamais en mémoire après cet appel.
#'
#' @param users Liste de listes. Chaque élément représente un utilisateur avec
#'   les champs :
#'   - `username` (obligatoire) : nom d'utilisateur
#'   - `password` (obligatoire) : mot de passe en clair, haché à l'appel
#'   - `role` (obligatoire) : `"user"`, `"admin"`, `"super_admin"` ou `"dev"`
#'   - `inactivity_delay` (optionnel, défaut `30`) : minutes d'inactivité
#'   - `active` (optionnel, défaut `TRUE`) : compte actif ou non
#'   - `expire_date` (optionnel, défaut `NA`) : date d'expiration (`Date` ou `NA`)
#'   - `dev_access` (optionnel, défaut `role == "dev"`) : accès host restreint
#'
#' @return `data.frame` avec colonnes : `userID`, `username`, `hash_password`,
#'   `role`, `created_by`, `inactivity_delay`, `active`, `expire_date`, `dev_access`.
#'
#' @export
#'
#' @importFrom sodium password_store
#' @importFrom rlang %||%
protegR2_build_local_users <- function(users) {
  rows <- lapply(seq_along(users), function(i) {
    u <- users[[i]]
    data.frame(
      userID           = i,
      username         = u$username,
      hash_password    = sodium::password_store(u$password),
      role             = u$role,
      created_by       = "local",
      inactivity_delay = u$inactivity_delay %||% 30,
      active           = if (is.null(u$active)) TRUE else u$active,
      expire_date      = if (is.null(u$expire_date)) as.Date(NA) else u$expire_date,
      dev_access       = if (is.null(u$dev_access)) u$role == "dev" else u$dev_access,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}


# ── config_user par défaut ─────────────────────────────────────────────────────
#
# Démontre la séparation rôle / config_user :
#   user1 et user2 ont le MÊME rôle ("user") mais voient des PAGES DIFFÉRENTES.
#   La page accessible dépend de config_user$protegr2$demopages, pas du rôle.
#
# user1 → "home" seulement   (pas "demo")
# user2 → "demo" seulement   (pas "home")
# Autres → "home" et "demo"
#
# Ce comportement n'est visible que dans les layouts multi-pages (sidebarHL,
# navbar). En mono-page (fluid, fillable), config_user n'affecte pas l'UI.
.local_config_user_default <- function() {
  list(
    user1       = list(protegr2 = list(demopages = c("home"))),
    user2       = list(protegr2 = list(demopages = c("demo"))),
    admin       = list(protegr2 = list(demopages = c("home", "demo"))),
    super_admin = list(protegr2 = list(demopages = c("home", "demo"))),
    dev         = list(protegr2 = list(demopages = c("home", "demo")))
  )
}


#' Créer une configuration locale minimale pour protegR2
#'
#' @description
#' Retourne un `config_global` complet et fonctionnel pour le mode
#' `user_config_backend = "local"`. Aucune connexion S3 ni PostgreSQL requise.
#'
#' ## Usage dans `pkg_shiny_test` (sans arguments)
#' ```r
#' config_global <- protegR2_local_config()
#' # → 5 utilisateurs par défaut (user1..dev) + config_user démo
#' ```
#'
#' ## Usage dans un projet utilisateur en mode local
#' ```r
#' # R/protegR2_local_users.R et R/protegR2_local_config_user.R
#' # sont copiés par protegR2_init_layout("local")
#' config_global <- protegR2_local_config(
#'   users       = protegR2_local_users(),
#'   config_user = protegR2_local_config_user()
#' )
#' ```
#'
#' @param users Liste de listes décrivant les utilisateurs, mots de passe en
#'   clair (voir [protegR2_build_local_users()]). `NULL` = 5 utilisateurs par
#'   défaut (`user1/pass1` … `dev/pass5`).
#' @param config_user Liste nommée par username contenant la `config_user` de
#'   chaque utilisateur. `NULL` = config démo (user1 → home, user2 → demo).
#' @param header_title Titre affiché dans le header.
#' @param cookie_name Nom du cookie de session navigateur.
#'
#' @return Liste `config_global` à assigner dans `global.R`.
#' @export
#'
#' @importFrom rlang %||%
protegR2_local_config <- function(
    users        = NULL,
    config_user  = NULL,
    header_title = "Application (mode local)",
    cookie_name  = "protegR2_local"
) {

  # ── Construction de users_auth ────────────────────────────────────────────
  # Le hachage bcrypt prend ~200ms par mot de passe.
  # On prévient l'utilisateur car le démarrage peut sembler lent.
  users_auth <- if (is.null(users)) {
    message("protegR2 — mode local : chargement des 5 utilisateurs par défaut...")
    protegR2_local_users_default()
  } else {
    n <- length(users)
    message("protegR2 — mode local : hachage des mots de passe (", n, " utilisateurs)...")
    protegR2_build_local_users(users)
  }
  message("protegR2 — mode local prêt. ",
          "Utilisateurs : ", paste(users_auth$username, collapse = ", "))

  # ── config_user ───────────────────────────────────────────────────────────
  config_user_final <- config_user %||% .local_config_user_default()

  # ── config_global complet ─────────────────────────────────────────────────
  list(
    protegR2 = list(

      header_title = header_title,
      cookie_name  = cookie_name,

      # ── Backend ───────────────────────────────────────────────────────────
      # Toutes les fonctions du package branchent sur cette valeur.
      user_config_backend = "local",

      # ── Données en mémoire ────────────────────────────────────────────────
      # Stockées dans config_global pour être accessibles via session$userData.
      # Jamais modifiées par l'app (lecture seule).
      local_users_auth  = users_auth,
      local_config_user = config_user_final,

      # ── Langue ────────────────────────────────────────────────────────────
      lang_choice  = TRUE,
      lang_default = "fr",
      lang_options = list(
        fr = list(mini_label = "FR", label = "Français"),
        en = list(mini_label = "EN", label = "English")
      ),

      # ── Thème ─────────────────────────────────────────────────────────────
      theme = list(bootswatch = "darkly", primary = "#3c8dbc"),

      # ── Google Analytics ──────────────────────────────────────────────────
      ga_id = NULL,

      # ── Sécurité ──────────────────────────────────────────────────────────
      security = list(
        token_check_interval_s = 45,
        cookie_throttle_ms     = 240000,
        max_login_attempts     = 5,
        lockout_duration_s     = 30
      ),

      # ── Page de login ─────────────────────────────────────────────────────
      login = list(
        background_img = "/images/background.png",
        welcome_text   = NULL,
        logo_url       = NULL,
        card_width_px  = 420
      ),

      # ── Hosts restreints ──────────────────────────────────────────────────
      # NULL = aucune restriction — tous les utilisateurs peuvent se connecter
      # depuis n'importe quel host. Cohérent avec l'usage local/dev.
      restricted_hosts = NULL
    ),

    # ── Sélecteur de langue (niveau racine de config_global) ──────────────
    show_idioma = TRUE,
    supported_idiomas = list(
      fr = list(mini_label = "FR", label = "Français"),
      en = list(mini_label = "EN", label = "English")
    )
  )
}

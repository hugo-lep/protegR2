# mots avec traduction, à utiliser avec utilsHL::make_tr(...)
print("i18n_db")
i18n_db <- list(

  # ── Page de login ──────────────────────────────────────────────────────────
  username = list(fr = "Utilisateur",   en = "Username", es = "Usuario"),
  password = list(fr = "Mot de passe",  en = "Password", es = "Contraseña"),
  login    = list(fr = "Connexion",     en = "Login",    es = "Acceso"),

  # ── Messages d'erreur de connexion ─────────────────────────────────────────
  # Message volontairement générique pour username/password invalides :
  # ne pas indiquer lequel est faux évite d'aider un attaquant à deviner les usernames.
  invalid_credentials = list(
    fr = "Nom d'utilisateur ou mot de passe incorrect.",
    en = "Invalid username or password.",
    es = "Nombre de usuario o contraseña incorrectos."
  ),
  empty_fields = list(
    fr = "Veuillez remplir tous les champs.",
    en = "Please fill in all fields.",
    es = "Por favor, complete todos los campos."
  ),
  inactive_account = list(
    fr = "Ce compte est désactivé. Contactez votre administrateur.",
    en = "This account is disabled. Contact your administrator.",
    es = "Esta cuenta está desactivada. Contacte a su administrador."
  ),
  expired_account = list(
    fr = "Ce compte a expiré. Contactez votre administrateur.",
    en = "This account has expired. Contact your administrator.",
    es = "Esta cuenta ha expirado. Contacte a su administrador."
  ),
  # Utilisé avec sprintf() — le %d sera remplacé par le nombre de secondes restantes.
  # Exemple : sprintf(tr("too_many_attempts"), 27) → "Trop de tentatives... attendez 27 s."
  too_many_attempts = list(
    fr = "Trop de tentatives échouées. Veuillez attendre %d seconde(s).",
    en = "Too many failed attempts. Please wait %d second(s).",
    es = "Demasiados intentos fallidos. Espere %d segundo(s)."
  ),

  # ── Accès restreint (host dev/staging) ────────────────────────────────────
  # Utilisées par check_host_access() dans protegR2_server() quand un utilisateur
  # tente d'accéder à un host restreint sans avoir dev_access = TRUE.
  access_denied = list(
    fr = "Accès refusé",
    en = "Access denied",
    es = "Acceso denegado"
  ),
  dev_access_required = list(
    fr = "Votre compte n'est pas autorisé à accéder à cette version de l'application.",
    en = "Your account is not authorized to access this version of the application.",
    es = "Su cuenta no está autorizada para acceder a esta versión de la aplicación."
  ),

  # ── Accès principal ─────────────────────────────────────────────────────────
  bienvenue = list(fr = "Bienvenue",    en = "Welcome",      es = "Bienvenido"),
  logout    = list(fr = "Déconnexion",  en = "Logout",       es = "Cerrar sesión"),

  # protegR2_load_modules_UIs
  menu1_sidebar_type_access = list(fr = "Menu 1: type d'accès", en = "Menu 1: Access type", es = "Menú 1: Tipo de acceso"),
  menu2_module_demo = list(fr = "Menu 2: module démo", en = "Menu 2: Demo module", es = "Menú 2: Módulo de demostración"),
  subItem_test = list(fr = "Test de sous-élément", en = "SubItem test", es = "Prueba de subelemento"),
  subitem1 = list(fr = "Sous-élément 1", en = "Subitem1", es = "Subítem1"),
  subitem2 = list(fr = "Sous-élément 2", en = "Subitem1", es = "Subítem1"),
  configuration = list(fr = "configuration", en = "configuration", es = "Configuración"),
  your_account = list(fr = "Votre compte", en = "Your account", es = "Tu perfil"),
  admin_access = list(fr = "Accès admin", en = "Admin. access", es = "Acceso de admin"),
  super_admin_access = list(fr = "Accès super-admin", en = "Super-admin access", es = "Acceso super-admin"),
  dev_access = list(fr = "Accès 'DEV'", en = "'Dev access", es = "Acceso'DEV"),


  #mod_demo1_ui
  contenu_du_module = list(fr = "Contenu du module", en = "Module Contents", es = "Contenido del módulo")
)

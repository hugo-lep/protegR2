print("protegR2_login_ui")

# Ce fichier est copié dans R/ de ton projet à l'initialisation.
# C'est ici que tu personnalises l'apparence de la page de connexion.
#
# Paramètres :
#   config_global  — liste de configuration chargée depuis S3 (contient header_title, etc.)
#   tr             — fonction de traduction (optionnelle, NULL si idioma = FALSE)
#
# Personnalisation :
#   - Fond       : modifier le CSS de .login-background (image, couleur, dégradé)
#   - Largeur    : modifier max-width dans .login-card-wrapper
#   - Apparence  : modifier les classes Bootstrap de la card (voir bslib)
#   - Champs     : ajouter / retirer des champs dans card_body()

protegR2_login_ui <- function(config_global, tr = NULL) {

  # Libellés traduits si tr() est disponible, sinon valeurs par défaut
  lbl_title    <- config_global$header_title %||% "Application"
  lbl_username <- if (!is.null(tr)) tr("username") else "Nom d'utilisateur"
  lbl_password <- if (!is.null(tr)) tr("password") else "Mot de passe"
  lbl_login    <- if (!is.null(tr)) tr("login")    else "Se connecter"

  tagList(

    # ── Fond plein écran ────────────────────────────────────────────────────────
    # Personnalise l'apparence dans le bloc CSS plus bas.
    tags$div(
      class = "login-background",

      # ── Card de connexion centrée ─────────────────────────────────────────────
      # max-width contrôlé par .login-card-wrapper dans le CSS
      div(
        class = "login-card-wrapper",

        card(
          # En-tête : titre de l'application
          card_header(
            class = "text-center fw-bold fs-5",
            lbl_title
          ),

          card_body(
            # Champs de connexion
            textInput("username",
                      label = lbl_username,
                      placeholder = lbl_username),

            passwordInput("password",
                          label = lbl_password,
                          placeholder = lbl_password),

            # Bouton pleine largeur (classe Bootstrap w-100)
            actionButton("login",
                         label = tagList(icon("right-to-bracket"), lbl_login),
                         class = "btn-primary w-100 mt-2")
          )
        )
      )
    ),

    # ── CSS de la page de login ─────────────────────────────────────────────────
    # Modifie ce bloc pour personnaliser l'apparence.
    #
    # Convention pour les images statiques :
    #   Les images vont dans inst/app/www/ du projet.
    #   global.R déclare : addResourcePath("images", "inst/app/www")
    #   → les images sont accessibles via l'URL /images/nom_du_fichier.
    #   Le CSS utilise donc url('/images/background.png'), pas url('background.png').
    #   (url('background.png') ne fonctionnerait que si l'image était dans www/
    #    à la racine du projet — le dossier servi automatiquement par Shiny.)
    tags$style(HTML("

      /* Fond plein écran — remplace background.png dans inst/app/www/ par ta propre image */
      .login-background {
        min-height: 100vh;
        width: 100%;
        background-image: url('/images/background.png');
        background-size: cover;
        background-position: center center;
        display: flex;
        align-items: center;
        justify-content: center;
      }

      /* Largeur et centrage de la card */
      .login-card-wrapper {
        width: 100%;
        max-width: 420px;
        padding: 20px;
      }

      /* Ombre portée sur la card */
      .login-card-wrapper .card {
        box-shadow: 0 8px 30px rgba(0, 0, 0, 0.4);
        border: none;
      }

    ")),

    # ── Touche Enter pour soumettre ─────────────────────────────────────────────
    # Permet de valider le formulaire avec Enter depuis les champs username et password.
    tags$script(HTML("
      $(document).on('keydown', '#username, #password', function(e) {
        if (e.key === 'Enter') {
          $(this).blur();      // force la mise à jour de la valeur côté Shiny
          $('#login').click(); // déclenche le bouton
          e.preventDefault();  // empêche le comportement par défaut du navigateur
        }
      });
    "))

  )
}

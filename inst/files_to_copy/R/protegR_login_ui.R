print("protegR_login_ui")
protegR_login_ui <- function(){
  tagList(
    tags$div(
      style = "
      min-height: 100vh;
      width: 100%;
      background-image: url('images/background.png');
      background-size: cover;
      background-position: center center;
      padding: 20px;
    ",
      div(
        textInput("username", "username"),
        passwordInput("password", "Password"),
        actionButton("login", "Login")
      )
    )
  )
}

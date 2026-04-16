#' get code from ip and user agent
#'
#' @param input input principal de la session shiny pour aller cherche information enregistré par nginx
#'
#' @return Un vecteur de type caractère représentant le fingerprint
#' @importFrom digest digest
#' @importFrom rlang `%||%`
#' @export
#'
#' @examples
#' if(interactive()){
#' get_fingerprint(input)
#' }

get_fingerprint <- function(input) {
  # client_data = input$client_ip_data envoyé par JS
  req(input$client_ip_data)

  ip <- input$client_ip_data$client_ip %||% "NA"
  ua <- input$client_ip_data$user_agent %||% "NA"
  language <- input$client_ip_data$language %||% "NA"
  timestamp <- input$client_ip_data$timestamp %||% "NA"
  fingerprint <- paste0(digest::digest(ip), "_", digest::digest(ua))

  list(
    ip = ip,
    ua = ua,
    language = language,
    timestamp = timestamp,
    fingerprint = fingerprint
  )
}

#' Fonction pour récupérer l'IP et le user agent
#' get user info
#'
#' @param session variable session de shiny
#' @param ns Namespace, utile quand utilisé dans un module
#' @param input_name client_ip_data par défaut
#'
#' @returns Rien mais ajoute un input
#' @export
#'
#' @examples
#' if(interactive()){
#' fetch_client_ip(session)
#' }
fetch_client_ip <- function(session, ns = NULL, input_name = "client_ip_data") {

  # Construction sécurisée de l'URL
  protocol <- session$clientData$url_protocol %||% "http:"
  host     <- session$clientData$url_hostname %||% "localhost"
  port     <- session$clientData$url_port
  path     <- session$clientData$url_pathname %||% "/"
  base_url <- paste0(protocol, "//", host,
                     if (!is.null(port) && port != "") paste0(":", port) else "",
                     path)
  base_url <- sub("/$", "", base_url)
  url <- paste0(base_url, "/api/get-client-ip")

  # Nom de l'input dans Shiny
  input_js <- if (!is.null(ns)) paste0(ns(input_name)) else input_name

  # JS pour fetch
  js_code <- glue::glue("
    fetch('{url}')
      .then(response => {{
        if (!response.ok) throw new Error('Erreur API: ' + response.status);
        return response.json();
      }})
      .then(data => {{
        Shiny.setInputValue('{input_js}', data, {{priority: 'event'}});
      }})
      .catch(error => {{
        console.error('fetch Error:', error);
        Shiny.setInputValue('{input_js}', {{ error: error.message }}, {{priority: 'event'}});
      }});
  ")

  runjs(js_code)
}

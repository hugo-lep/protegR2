# ── DÉPRÉCIÉ ────────────────────────────────────────────────────────────────────
# add_mod_ui() et add_mod_ui_sub() sont des fonctions de l'ère shinydashboard.
# Elles construisaient deux listes parallèles (menu_items + tab_items) liées par
# des strings tabName — un pattern fragile et verbeux.
#
# Avec bslib, ce pattern est remplacé par nav_panel() et nav_menu() qui combinent
# titre et contenu dans un seul objet. Ces fonctions ne sont plus utilisées.
# Conservées ici temporairement pour référence, à supprimer dans une version future.
# ────────────────────────────────────────────────────────────────────────────────

#' @title \[DÉPRÉCIÉ\] Fonction pour ajouter des menuItems dans le "sidebar"
#'
#' @description
#' Déprécié depuis protegR2. Utiliser `nav_panel()` et `nav_menu()` de bslib.
#'
#' @param my_dashboard Fichier contenant les menu_items et tab_items sélectionnés
#' @param menu_title Titre qu'on veut voir apparaitre dans le "sidebar"
#' @param my_tabName Mot servant à faire le lien entre la selection dans le sidebar et le tabItem (une sorte de ID)
#' @param ui ui à ajouter
#' @param subitems subitem, introduit avec: list(add_mod_ui_sub(...),add_mod_ui_sub(...),...)
#'
#' @importFrom purrr compact map
#'
#' @returns Un menuItem aini que les les différents tabItem inclus dans celui-ci
#' @export
#'
#' @examples
#' if(interactive()){
#' add_mod_ui("my_dashboard","menu_title","my_tabName")
#' }
add_mod_ui <- function(my_dashboard, menu_title, my_tabName, ui = NULL, subitems = NULL) {

  #option où subitems est NULL parce qu'on proposer un menuItem
  if (is.null(subitems)) {
    print("option 1: pas de subitems, donc ui ajouté (menu + tab)")
    my_dashboard$menu_items <- append(my_dashboard$menu_items, list(menuItem(menu_title, tabName = my_tabName)))
    my_dashboard$tab_items <- append(my_dashboard$tab_items, list(tabItem(tabName = my_tabName, ui)))

    # option où tous les subitems sont vide, alors, on retourne le my_dashboard original
  } else if (length(compact(subitems)) == 0) {
    print("option 2: subitems, mais tout null, my_dashboard original retourné")
  } else {
    print("option 3")

    subitems2 <- list(sub_menu_items = list(), tab_items = list())
    subitems2 <- compact(subitems)

    my_dashboard$menu_items <- append(
      my_dashboard$menu_items,
      list(do.call(menuItem, c(list(menu_title), map(subitems2, "menu_sub_items"))))
    )

    my_dashboard$tab_items <- c(my_dashboard$tab_items,
                                map(subitems2, "tab_items"))
  }
  return(my_dashboard)
}

#' @title \[DÉPRÉCIÉ\] Fonction pour ajouter des sous-modules à l'application
#'
#' @description
#' Déprécié depuis protegR2. Utiliser `nav_panel()` dans un `nav_menu()` de bslib.
#'
#' @param condition (boolean) Condition si cet item est ajouté ou pas au dashboard
#' @param sub_title Titre du menuSubItem dans le "sidebar"
#' @param my_tabName Mot servant à faire le lien entre la selection dans le sidebar et le tabItem (une sorte de ID)
#' @param ui section UI du module qu'on veut ajouter à l'application
#'
#' @returns Ajoute un menu_sub_item et tab_item
#' @export
#'
#' @examples
#' if(interactive()){
#' add_mod_ui_sub(condition, sub_title, my_tabName, ui)
#' }
add_mod_ui_sub <- function(condition, sub_title, my_tabName, ui) {

  if (!condition) {
    return(NULL)
  }

  subitems <- list()
  subitems$menu_sub_items <- menuSubItem(sub_title, tabName = my_tabName)
  subitems$tab_items <-      tabItem(tabName = my_tabName, ui)
  subitems
}

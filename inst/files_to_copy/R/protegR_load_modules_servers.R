print("protegR_load_modules_servers")
protegR_load_modules_servers <- function(sessions,
                                         input_main_app,
                                         main_session) {
  mod_demo1_server("demo1")
  mod_demo_subitem1_server("subitem1")
  mod_config_server("config",
                    sessions = sessions,
                    input_main_app = input_main_app,
                    main_session = main_session)
  mod_demo_airplane_server("turn_plane")
}

import Config

config :checker, url_util: Checker.Util

import_config "#{config_env()}.exs"

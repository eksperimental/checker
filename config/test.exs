import Config

config :checker, url_util: Checker.Mock

config :logger,
  backends: [:console],
  compile_time_purge_matching: [
    [level_lower_than: :warning]
  ]

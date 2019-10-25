import Config

# Nostrum configuration
config :nostrum,
  # Discord token
  token: "TOKEN",
  num_shards: :auto

# o2m configuration
config :o2m,
  # Username on Discord
  username: "Orgie 2 Metal",
  # Prefix used for commands
  prefix: System.get_env("O2M_PREFIX", "!"),
  # Metalorgie url, used for `band` and `album` command
  metalorgie: "https://www.metalorgie.com",
  # Time between each check on Ausha
  timer: System.get_env("O2M_AUSHA_TIMER", "500"),
  # Channel ID
  chan: System.get_env("O2M_CHAN_ID"),
  # RSS Ausha slug (full url example : https://feed.ausha.co/owAEhJ0qOPkb)
  ausha_slugs: System.get_env("O2M_AUSHA_SLUGS")

import Config

# Nostrum configuration
config :nostrum,
  # Discord token
  token: System.get_env("DISCORD_TOKEN"),
  num_shards: :auto

# o2m configuration
config :o2m,
  # Username on Discord
  username: System.get_env("O2M_USERNAME"),
  # Prefix used for commands
  prefix: "!",
  # Metalorgie url, used for `band` and `album` command
  metalorgie: "https://www.metalorgie.com",
  # Time between each check on Ausha
  timer: 5,
  # Channel ID
  chan: System.get_env("O2M_CHAN_ID"),
  # RSS Ausha slug (full url example : https://feed.ausha.co/owAEhJ0qOPkb)
  ausha_slug: System.get_env("O2M_AUSHA_SLUG")
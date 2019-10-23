import Config

# Nostrum configuration
config :nostrum,
  # Discord token
  token: "NjM0NjM0NzU0NTQ5MDg4MjU2.XalgTw.QP4hJRBt8oqlELkeYpkmrbkCv14",
  num_shards: :auto

# o2m configuration
config :o2m,
  # Username on Discord
  username: "Orgie 2 Metal",
  # Prefix used for commands
  prefix: "!",
  # Metalorgie url, used for `band` and `album` command
  metalorgie: "https://www.metalorgie.com",
  # Time between each check on Ausha
  timer: 5,
  # Channel ID
  chan: 628_119_686_910_967_808,
  # RSS Ausha slug (full url example : https://feed.ausha.co/owAEhJ0qOPkb)
  ausha_slug: "owAEhJ0qOPkb"

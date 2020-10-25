# import config
import Config

# Nostrum configuration
config :nostrum,
  # Discord token
  token: System.get_env("DISCORD_TOKEN"),
  num_shards: :auto

# o2m configuration
config :o2m,
  # Nickname on Discord
  nickname: System.get_env("O2M_NICKNAME", "Orgie 2 Metal"),
  # Prefix used for commands
  prefix: System.get_env("O2M_PREFIX", "!"),
  # Metalorgie url, used for `band` and `album` command
  metalorgie: "https://www.metalorgie.com",
  # Time between each check on feeds
  timer: System.get_env("O2M_JOBS_TIMER", "500"),
  # Guild ID
  guild: System.get_env("O2M_GUILD_ID"),
  # Channel ID
  chan: System.get_env("O2M_CHAN_ID"),
  # RSS podcast feed urls
  feed_urls: System.get_env("O2M_FEED_URLS"),
  # DETS template file
  tmpl_dets: System.get_env("O2M_TMPL_DETS", "/opt/o2m/dets/templates.dets")

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:url, :init, :data, :state, :template, :reason, :code],
  level: :info

config :porcelain,
  driver: Porcelain.Driver.Basic

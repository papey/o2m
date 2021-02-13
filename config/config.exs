# Ensure Mix.config is loaded
use Mix.Config

# Nostrum configuration
config :nostrum,
  # Discord token
  token: System.get_env("DISCORD_TOKEN"),
  num_shards: :auto,
  gateway_intents:
    if(System.get_env("DISCORD_GW_INTENTSjjj") == "yes", do: :all, else: :nonprivileged)

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
  tmpl_dets: System.get_env("O2M_TMPL_DETS", "/srv/o2m/dets/templates.dets"),
  # Blind tests
  # admin role for blind-test
  bt_admin: System.get_env("O2M_BT_ADMIN"),
  # text channel for blind-tests
  bt_chan: System.get_env("O2M_BT_CHAN_ID"),
  # text channel for blind-tests
  bt_vocal: System.get_env("O2M_BT_VOCAL_ID"),
  # cache diredctory for songs
  bt_cache: System.get_env("O2M_BT_CACHE", "/tmp/o2m/cache"),
  # blind test leaderbord dets
  bt_lboard_dets: System.get_env("O2M_BT_LBOARD_DETS", "/srv/o2m/dets/leaderboard.dets")

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [
    :url,
    :init,
    :data,
    :state,
    :template,
    :reason,
    :code,
    :retries,
    :current,
    :sub,
    :message
  ],
  level: :info

config :porcelain,
  driver: Porcelain.Driver.Basic

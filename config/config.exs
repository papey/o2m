# Ensure Mix.config is loaded
import Config

# Nostrum configuration
config :nostrum,
  # Discord token
  token: System.get_env("DISCORD_TOKEN"),
  num_shards: :auto,
  gateway_intents:
    if(System.get_env("DISCORD_GW_INTENTS") == "yes", do: :all, else: :nonprivileged)

# o2m configuration
config :o2m,
  # Metalorgie url, used for `band` and `album` command
  metalorgie: "https://www.metalorgie.com"

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

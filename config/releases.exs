# import config
import Config

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

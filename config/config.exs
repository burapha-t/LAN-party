# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Configures the endpoint
config :lan_party, LanPartyWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: LanPartyWeb.ErrorHTML, json: LanPartyWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: LanParty.PubSub,
  live_view: [signing_salt: "7XcJgfp4"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  lan_party: [
    args: ~w(js/app.js css/app.css --bundle --target=es2022 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Seconds-scale settings for the platform. See CLAUDE.md "Disconnects".
config :lan_party, grace_ms: 30_000, print_urls: true

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

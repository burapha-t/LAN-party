import Config

# Bind to all interfaces (0.0.0.0) so phones on the LAN can reach the server.
# check_origin is off because phones connect from the LAN IP.
config :lan_party, LanPartyWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT") || "4000")],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "uPp8zbjYSxCV8TfH9v2zb9be7jtsyvnFEyY93DpBVfxQSxFrbtWBSGlZN1I8K9t",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:lan_party, ~w(--sourcemap=inline --watch)]}
  ]

# Watch static and templates for browser reloading.
config :lan_party, LanPartyWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/lan_party_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :default_formatter, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Include HEEx debug annotations as HTML comments in rendered markup.
  debug_heex_annotations: true,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true

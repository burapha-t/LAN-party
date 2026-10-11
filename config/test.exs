import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :lan_party, LanPartyWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "qDK75qUyprohDrgGMA4EKUyBX5z0QPckBssJfH5L2U9G4tbnrpkKVj3faXBJVt9",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :lan_party, grace_ms: 50, print_urls: false

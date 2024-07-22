import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :callbreak, CallbreakWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "OZDOhy/OfNpG+XtZ+cM3nRL910Sk1aMkMk7eVGyPc4IAy79WZPPxQ7+B0+dwj2Zf",
  server: false

# In test we don't send emails.
config :callbreak, Callbreak.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

import Config

config :nostrum,
  token: System.get_env("DISCORD_API_KEY"),
  num_shards: :auto,
  gateway_intents: :all

config :porcelain, :driver, Porcelain.Driver.Basic

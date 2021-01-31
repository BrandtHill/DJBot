import Config

config :nostrum,
  token: System.get_env("DISCORD_API_KEY"),
  #gateway_intents: :all,
  num_shards: :auto

config :porcelain, :driver, Porcelain.Driver.Basic

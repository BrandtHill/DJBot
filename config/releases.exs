import Config

config :nostrum,
  token: System.get_env("DISCORD_API_KEY"),
  num_shards: :auto,
  gateway_intents: :all

config :logger, :console, metadata: [:shard, :guild, :channel]

config :porcelain, :driver, Porcelain.Driver.Basic

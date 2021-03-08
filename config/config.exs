import Config

config :nostrum,
  token: System.get_env("DISCORD_API_KEY"),
  #gateway_intents: :all,
  num_shards: :auto

config :logger, :console, metadata: [:shard, :guild, :channel]

config :porcelain, :driver, Porcelain.Driver.Basic

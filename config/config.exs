import Config

config :nostrum,
  token: System.get_env("DISCORD_API_KEY")

config :logger, :console, metadata: [:shard, :guild, :channel], level: :info

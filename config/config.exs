import Config

config :logger, :console, metadata: [:shard, :bot, :guild, :channel], level: :info

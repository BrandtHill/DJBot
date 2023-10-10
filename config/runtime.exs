import Config

config :nostrum,
  token: System.get_env("DISCORD_API_KEY"),
  youtubedl: "yt-dlp"

config :logger, :console, metadata: [:shard, :guild, :channel], level: :info

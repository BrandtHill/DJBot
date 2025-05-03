import Config

config :nostrum, youtubedl: "yt-dlp"

config :djbot, :discord_api_key, System.fetch_env!("DISCORD_API_KEY")

config :logger, :console, metadata: [:shard, :bot, :guild, :channel], level: :info

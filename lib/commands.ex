defmodule Djbot.Commands do
  alias Djbot.{ActiveStates, PlayingQueues}
  alias Nostrum.Voice

  require Logger

  @check ":white_check_mark:"

  @play_opts [
    %{
      type: 3,
      name: "url",
      description: "Which file or URL to play",
      required: true
    },
    %{
      type: 10,
      name: "volume",
      description: "Volume of audio (1.0 is normal)"
    },
    %{
      type: 5,
      name: "realtime",
      description: "Use realtime ffmpeg processing (true by default)"
    },
    %{
      type: 3,
      name: "start_time",
      description: "Timestamp to start audio playback at"
    },
    %{
      type: 3,
      name: "duration",
      description: "Length of audio to play"
    },
    %{
      type: 3,
      name: "filters",
      description: "FFmpeg filters to apply to the audio"
    }
  ]

  @skip_opts [
    %{
      type: 4,
      name: "amount",
      description: "Number of queued URLs to skip (default 1)",
      min_value: 1
    }
  ]

  @show_opts [
    %{
      type: 4,
      name: "amount",
      description: "Number of queued URLs to show (default 5)",
      min_value: 1
    }
  ]

  @commands %{
    "help" => {:help, "Show all commands", []},
    "play" => {:play, "Play (or queue) URLs from common service", @play_opts},
    "playfile" => {:play, "Play (or queue) files from URL", @play_opts},
    "playdir" => {:play, "Play (or queue) directory of files", @play_opts},
    "stop" => {:stop, "Stop the currently playing sound and empty queue", []},
    "pause" => {:pause, "Pause the currently playing sound", []},
    "resume" => {:resume, "Resume the currently paused sound", []},
    "skip" => {:skip, "Skip to next queued track", @skip_opts},
    "show" => {:show, "Show to next few queued URLs/files", @show_opts},
    "summon" => {:summon, "Summon DJ Bot to your voice channel", []},
    "leave" => {:leave, "Tell DJ Bot to leave your voice channel", []}
  }

  def checkmark_emoji, do: @check

  def commands, do: @commands

  def dispatch(%{data: %{name: cmd}} = interaction) do
    case Map.get(@commands, cmd) do
      {function, _, _} -> :erlang.apply(__MODULE__, function, [interaction])
      nil -> nil
    end
  end

  def help(_interaction) do
    Enum.map_join(@commands, "\n", fn {cmd, {_, desc, _}} ->
      "/#{cmd} - #{desc}"
    end)
  end

  def play(%{guild_id: guild_id, data: %{name: cmd, options: options}} = _interaction) do
    if Voice.ready?(guild_id) do
      type = get_play_type(cmd)
      opts = Enum.flat_map(options, &parse_option/1)

      get_input_list(cmd, opts[:input]) |> Enum.each(&enqueue_url(guild_id, &1, type, opts))
    else
      "I must be summoned to a voice channel before playing."
    end
  rescue
    _ -> improperly_formatted(cmd)
  end

  defp get_play_type("play"), do: :ytdl
  defp get_play_type(_cmd), do: :url

  defp get_input_list("playdir", input), do: get_audio_files(input)
  defp get_input_list(_cmd, input), do: [input]

  def summon(%{guild_id: guild_id} = interaction) do
    case get_voice_channel_of_interaction(interaction) do
      nil ->
        "You must be in a voice channel to summon me."

      voice_channel_id ->
        Voice.join_channel(guild_id, voice_channel_id)

        unless PlayingQueues.get_queue(guild_id),
          do: PlayingQueues.set_queue(guild_id, :queue.new())
    end
  end

  def leave(%{guild_id: guild_id} = _interaction) do
    Voice.leave_channel(guild_id)
    PlayingQueues.remove_queue(guild_id)
  end

  def stop(%{guild_id: guild_id} = _interaction) do
    ActiveStates.set_active(guild_id, false)
    ActiveStates.set_playing(guild_id, nil)
    PlayingQueues.set_queue(guild_id, :queue.new())
    Voice.stop(guild_id)
  end

  def pause(%{guild_id: guild_id} = _interaction) do
    ActiveStates.set_active(guild_id, false)
    Voice.pause(guild_id)
  end

  def resume(%{guild_id: guild_id} = _interaction) do
    ActiveStates.set_active(guild_id, true)
    Voice.resume(guild_id)
  end

  def skip(%{guild_id: guild_id, data: %{options: options}} = _interaction) do
    num =
      case options do
        [%{name: "amount", value: v}] when is_integer(v) and v > 0 -> v
        _ -> 1
      end

    guild_id
    |> PlayingQueues.get_queue()
    |> :queue.to_list()
    |> Enum.drop(num - 1)
    |> :queue.from_list()
    |> then(&PlayingQueues.set_queue(guild_id, &1))

    ActiveStates.set_active(guild_id, false)
    Voice.stop(guild_id)
    trigger_play(guild_id)
    ActiveStates.set_active(guild_id, true)
  end

  def show(%{guild_id: guild_id, data: %{options: options}} = _interaction) do
    num =
      case options do
        [%{name: "amount", value: v}] when is_integer(v) and v > 0 -> v
        _ -> 5
      end

    playing =
      case ActiveStates.get_playing(guild_id) do
        nil -> ""
        input -> "Now playing: #{input}\n"
      end

    playing <> "Up next:\n" <> peek_queue(guild_id, num)
  end

  def enqueue_url(guild_id, input, type, options) do
    q = PlayingQueues.get_queue(guild_id)
    if :queue.len(q) == 0, do: ActiveStates.set_active(guild_id, true)
    q = :queue.in({input, type, options}, q)
    PlayingQueues.set_queue(guild_id, q)
    unless Voice.playing?(guild_id), do: trigger_play(guild_id)
  end

  def trigger_play(guild_id) do
    q = PlayingQueues.get_queue(guild_id)

    case :queue.out(q) do
      {{:value, {input, type, options}}, q} ->
        Logger.info("Playing next track #{input}")
        ActiveStates.set_playing(guild_id, input)
        PlayingQueues.set_queue(guild_id, q)
        Voice.play(guild_id, input, type, options)

      {:empty, _q} ->
        Logger.debug("DJ Bot Queue Empty for #{guild_id}")
        ActiveStates.set_playing(guild_id, nil)
    end
  end

  def peek_queue(guild_id, num_to_show \\ 5) do
    guild_id
    |> PlayingQueues.get_queue()
    |> :queue.to_list()
    |> Stream.take(num_to_show)
    |> Stream.with_index(1)
    |> Enum.map_join("\n", fn {x, i} -> "#{i}: #{elem(x, 0)}" end)
  end

  def get_voice_channel_of_interaction(%{guild_id: guild_id, user: %{id: user_id}} = _interaction) do
    guild_id
    |> Nostrum.Cache.GuildCache.get!()
    |> Map.get(:voice_states)
    |> Enum.find(%{}, &(&1.user_id == user_id))
    |> Map.get(:channel_id)
  end

  defp parse_option(%{name: "url", value: v}), do: [input: v]
  defp parse_option(%{name: "volume", value: v}), do: [volume: v]
  defp parse_option(%{name: "realtime", value: v}), do: [realtime: v]
  defp parse_option(%{name: "start_time", value: v}), do: [start_pos: v]
  defp parse_option(%{name: "duration", value: v}), do: [duration: v]
  defp parse_option(%{name: "filters", value: v}), do: String.split(v) |> Enum.map(&{:filter, &1})
  defp parse_option(_), do: []

  def get_audio_files(path) do
    path
    |> File.ls!()
    |> Stream.map(&"#{path}/#{&1}")
    |> Stream.flat_map(fn f -> if File.dir?(f), do: get_audio_files(f), else: [f] end)
    |> Stream.filter(&Regex.match?(~r/\.(mp3|m4a|wav|aiff|flac|ogg|aac|wma)$/i, &1))
    |> Enum.shuffle()
  end

  defp improperly_formatted(cmd), do: "Improperly formatted `#{cmd}` command."
end

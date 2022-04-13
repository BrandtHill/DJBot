defmodule Djbot.Commands do
  alias Djbot.{ActiveStates, EmbedUtils, PlayingQueues, Soundboard}
  alias Nostrum.Struct.Component.{ActionRow, Button}
  alias Nostrum.Voice

  require Logger

  opt = fn type, name, desc, opts ->
    %{type: type, name: name, description: desc}
    |> Map.merge(Enum.into(opts, %{}))
  end

  @play_opts [
    opt.(3, "url", "Which file or URL to play", required: true),
    opt.(10, "volume", "Volume of audio (1.0 is normal)", []),
    opt.(5, "realtime", "Use realtime ffmpeg processing (true by default)", []),
    opt.(3, "start_time", "Timestamp to start audio playback at", []),
    opt.(3, "duration", "Length of audio to play", []),
    opt.(3, "filters", "FFmpeg filters to apply to the audio", [])
  ]

  @soundboard_opts [
    opt.(1, "show", "Show the current soundboard", []),
    opt.(1, "add", "Add a sound to the soundboard",
      options: [
        opt.(3, "name", "Unique name for the sound", required: true),
        opt.(3, "url", "URL of the sound", required: true)
      ]
    ),
    opt.(1, "remove", "Remove a sound from the soundboard",
      options: [
        opt.(3, "name", "Name of the sound to remove", required: true)
      ]
    )
  ]

  @skip_opts [
    opt.(4, "amount", "Number of queued URLs to skip (default 1)", min_value: 1)
  ]

  @show_opts [
    opt.(4, "amount", "Number of queued URLs to show (default 5)", min_value: 1)
  ]

  @commands %{
    "help" => {:help, "Show all commands", []},
    "play" => {:play, "Play (or queue) URLs from common service", @play_opts},
    "playfile" => {:play, "Play (or queue) files from URL", @play_opts},
    "playdir" => {:play, "Play (or queue) directory of files", @play_opts},
    "soundboard" => {:soundboard, "Interact with a soundboard", @soundboard_opts},
    "stop" => {:stop, "Stop the currently playing sound and purge queue", []},
    "pause" => {:pause, "Pause the currently playing sound", []},
    "resume" => {:resume, "Resume the currently paused sound", []},
    "skip" => {:skip, "Skip to next queued track", @skip_opts},
    "show" => {:show, "Show the next few queued URLs", @show_opts},
    "summon" => {:summon, "Summon DJ Bot to your voice channel", []},
    "leave" => {:leave, "Tell DJ Bot to leave your voice channel", []}
  }

  def commands, do: @commands

  @emoji_pause ":pause_button:"
  @emoji_resume ":play_pause:"
  @emoji_stop ":stop_button:"
  @emoji_skip ":fast_forward:"
  @emoji_leave ":wave:"
  @emojis ~w(:headphones: :loud_sound: :arrow_forward: :notes:)
  @emojis_structs ["🎶", "▶️", "🔊", "🎧"] |> Enum.map(&%{id: nil, name: &1})

  def rand_emoji, do: Enum.random(@emojis)
  def rand_emoji_s, do: Enum.random(@emojis_structs)

  # Button presses
  def dispatch(%{data: %{name: nil, component_type: 2}} = interaction) do
    soundboard_play(interaction)
  end

  # Slash commands
  def dispatch(%{data: %{name: cmd}} = interaction) do
    case Map.get(@commands, cmd) do
      {function, _, _} -> :erlang.apply(__MODULE__, function, [interaction])
      nil -> nil
    end
  end

  def help(_interaction) do
    {:msg, Enum.map_join(@commands, "\n", fn {cmd, {_, desc, _}} -> "/#{cmd} - #{desc}" end)}
  end

  def play(%{guild_id: guild_id, data: %{name: cmd, options: options}} = _interaction) do
    if Voice.ready?(guild_id) do
      type = play_type(cmd)
      opts = Enum.flat_map(options, &parse_option/1)

      url_list(cmd, opts[:url]) |> Enum.each(&enqueue_url(guild_id, &1, type, opts))

      if PlayingQueues.empty?(guild_id),
        do: {:msg, "Playing now #{rand_emoji()}"},
        else: {:msg, "Audio queued #{rand_emoji()}"}
    else
      {:msg, "I must be summoned to a voice channel before playing."}
    end
  end

  defp play_type("play"), do: :ytdl
  defp play_type(_cmd), do: :url
  defp url_list("playdir", url), do: get_audio_files(url)
  defp url_list(_cmd, url), do: [url]

  def soundboard(%{guild_id: guild_id, data: %{options: [%{name: "show"}]}} = _interaction) do
    {:components, soundboard_buttons(guild_id)}
  end

  def soundboard(%{guild_id: guild_id, data: %{options: [%{name: "add", options: opts}]}}) do
    if Soundboard.get_sound_names(guild_id) |> length() < 25 do
      [%{name: "name", value: name}, %{name: "url", value: url}] = opts
      func = fn -> Soundboard.add_sound(guild_id, name, url) end
      {:msg_after, func, "`#{name}` downloaded to soundboard"}
    else
      {:msg, "Only 25 sounds allowed per guild. Either delete or overwrite a sound."}
    end
  end

  def soundboard(%{guild_id: guild_id, data: %{options: [%{name: "remove", options: opts}]}}) do
    [%{name: "name", value: name}] = opts
    Soundboard.delete_sound(guild_id, name)
    {:msg, "`#{name}` removed from soundboard"}
  end

  def soundboard_buttons(guild_id) do
    Soundboard.get_sound_names(guild_id)
    |> Enum.map(&Button.interaction_button(&1, &1, style: 2, emoji: rand_emoji_s()))
    |> Enum.chunk_every(5)
    |> Enum.map(&ActionRow.action_row(components: &1))
  end

  def soundboard_play(%{guild_id: guild_id, data: %{custom_id: name}} = _interaction) do
    case Soundboard.get_sound(guild_id, name) do
      nil ->
        nil

      sound ->
        delete_playing_message(guild_id)
        active? = ActiveStates.is_active?(guild_id)
        ActiveStates.set_active(guild_id, false)
        Voice.stop(guild_id)
        Voice.play(guild_id, sound, :raw)
        ActiveStates.set_active(guild_id, active?)
    end

    :empty
  end

  def summon(%{guild_id: guild_id, channel_id: channel_id} = interaction) do
    case get_voice_channel_of_interaction(interaction) do
      nil ->
        {:msg, "You must be in a voice channel to summon me."}

      voice_channel_id ->
        Voice.join_channel(guild_id, voice_channel_id)
        ActiveStates.set_channel_id(guild_id, channel_id)
        PlayingQueues.assert(guild_id)
        {:msg, "I'm here #{rand_emoji()}"}
    end
  end

  def leave(%{guild_id: guild_id} = _interaction) do
    ActiveStates.set_active(guild_id, false)
    ActiveStates.set_current_url(guild_id, nil)
    PlayingQueues.remove(guild_id)
    Voice.leave_channel(guild_id)
    {:msg, "Later #{@emoji_leave}"}
  end

  def stop(%{guild_id: guild_id} = _interaction) do
    ActiveStates.set_active(guild_id, false)
    ActiveStates.set_current_url(guild_id, nil)
    PlayingQueues.purge(guild_id)
    Voice.stop(guild_id)
    delete_playing_message(guild_id)
    {:msg, "Stopped and purged queue #{@emoji_stop}"}
  end

  def pause(%{guild_id: guild_id} = _interaction) do
    ActiveStates.set_active(guild_id, false)
    Voice.pause(guild_id)
    {:msg, "Paused #{@emoji_pause}"}
  end

  def resume(%{guild_id: guild_id} = _interaction) do
    ActiveStates.set_active(guild_id, true)
    Voice.resume(guild_id)
    {:msg, "Resumed #{@emoji_resume}"}
  end

  def skip(%{guild_id: guild_id, data: %{options: options}} = _interaction) do
    num =
      case options do
        [%{name: "amount", value: v}] when is_integer(v) and v > 0 -> v
        _ -> 1
      end

    ActiveStates.set_active(guild_id, false)
    PlayingQueues.pop(guild_id, num - 1)
    Voice.stop(guild_id)
    trigger_play(guild_id)
    {:msg, "Skipped #{num} #{@emoji_skip}"}
  end

  def show(%{guild_id: guild_id, data: %{options: options}} = _interaction) do
    num =
      case options do
        [%{name: "amount", value: v}] when is_integer(v) and v > 0 -> v
        _ -> 5
      end

    task = Task.async(EmbedUtils, :create_now_playing_embed, [guild_id])

    up_next =
      case peek_queue(guild_id, num) do
        [] -> []
        urls -> [EmbedUtils.create_up_next_embed(urls)]
      end

    now_playing = Task.await(task)
    {:embeds, [now_playing | up_next]}
  end

  def enqueue_url(guild_id, url, type, options) do
    PlayingQueues.push(guild_id, {url, type, options})
    unless Voice.playing?(guild_id), do: trigger_play(guild_id)
  end

  def trigger_play(guild_id) do
    case PlayingQueues.pop(guild_id) do
      [{url, type, options}] ->
        Logger.info("Playing next track #{url}")
        ActiveStates.set_active(guild_id, true)
        ActiveStates.set_current_url(guild_id, url)
        Voice.play(guild_id, url, type, options)

      [] ->
        ActiveStates.set_current_url(guild_id, nil)
        Logger.debug("DJ Bot Queue Empty for #{guild_id}")
    end

    create_playing_message(guild_id)
  end

  def peek_queue(guild_id, num_to_show \\ 5) do
    PlayingQueues.peek(guild_id, num_to_show)
    |> Enum.map(&elem(&1, 0))
  end

  def get_voice_channel_of_interaction(%{guild_id: guild_id, user: %{id: user_id}} = _interaction) do
    guild_id
    |> Nostrum.Cache.GuildCache.get!()
    |> Map.get(:voice_states)
    |> Enum.find(%{}, &(&1.user_id == user_id))
    |> Map.get(:channel_id)
  end

  defp parse_option(%{name: "url", value: v}), do: [url: v]
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

  def delete_playing_message(guild_id) do
    case ActiveStates.get_last_msg(guild_id) do
      nil -> :noop
      msg -> Nostrum.Api.delete_message(msg)
    end

    ActiveStates.set_last_msg(guild_id, nil)
  end

  def create_playing_message(guild_id) do
    delete_playing_message(guild_id)

    if ActiveStates.get_current_url(guild_id) do
      case(
        Nostrum.Api.create_message(ActiveStates.get_channel_id(guild_id),
          embed: EmbedUtils.create_now_playing_embed(guild_id)
        )
      ) do
        {:ok, msg} -> ActiveStates.set_last_msg(guild_id, msg)
        _ -> ActiveStates.set_last_msg(guild_id, nil)
      end
    end
  end
end

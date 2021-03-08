defmodule Djbot.Commands do

  alias Djbot.{ActiveStates, Queues}
  alias Nostrum.{Api, Voice}

  require Logger

  @prefix "~"

  @commands %{
    "help"      => {&__MODULE__.help/2, "Show all commands", "help"},
    "play"      => {&__MODULE__.play/2, "Play (or queue) URLs from common service", "play [-r true|false] [-s {START_TIME}] [-d {DURATION}] [-v {VOLUME}] [-f {FILTER}] {URL}"},
    "playfile"  => {&__MODULE__.play/2, "Play (or queue) files from URL", "playfile [-r true|false] [-s {START_TIME}] [-d {DURATION}] [-v {VOLUME}] [-f {FILTER}] {FILE_URL}"},
    "playdir"   => {&__MODULE__.play/2, "Play (or queue) directory of files", "playdir [-r true|false] [-s {START_TIME}] [-d {DURATION}] [-v {VOLUME}] [-f {FILTER}] {DIRECTORY}"},
    "stop"      => {&__MODULE__.stop/2, "Stop the currently playing sound and empty queue", "stop"},
    "pause"     => {&__MODULE__.pause/2, "Pause the currently playing sound", "pause"},
    "resume"    => {&__MODULE__.resume/2, "Resume the currently paused sound", "resume"},
    "skip"      => {&__MODULE__.skip/2, "Skip to next queued track", "skip [{NUM_TO_SKIP} \\ 1]"},
    "show"      => {&__MODULE__.show/2, "Show to next few queued URLs/files", "show [{NUM_TO_SHOW} \\ 5}]"},
    "summon"    => {&__MODULE__.summon/2, "Make the bot join your voice channel", "summon"},
    "leave"     => {&__MODULE__.leave/2, "Make the bot leave your voice channel", "leave"},
  }

  def command_prefix, do: @prefix

  def dispatch(cmd, msg) do
    case Map.get(@commands, cmd) do
      {function, _, _} -> function.(cmd, msg)
      nil -> nil
    end
  end

  def help(_cmd, msg) do
    content = @commands
    |> Enum.reduce("", fn {cmd, {_, desc, usage}}, acc -> acc <> "#{@prefix}#{cmd} - #{desc} - #{@prefix}#{usage}\n" end)
    Api.create_message(msg.channel_id, content)
  end

  def play(cmd, msg) do
    matches = Regex.named_captures(~r/^#{@prefix}\s*(?<cmd>#{cmd})\s+(?<args>.+)/i, msg.content)
    try do
      if Voice.ready?(msg.guild_id) do
        unless matches, do: raise "Error"
        type = if(cmd == "play", do: :ytdl, else: :url)
        opts = parse_args(matches["args"])
        Logger.debug("Command: #{cmd}, Opts: #{inspect(opts)}")
        opts[:error] && raise "Error"

        if(cmd == "playdir", do: get_audio_files(opts[:input]), else: [opts[:input]])
        |> List.flatten()
        |> Enum.each(&enqueue_url(msg.guild_id, &1, type, opts))
      else
        Api.create_message(msg.channel_id, "I must be summoned to a voice channel before playing.")
      end
    rescue
      _ -> Api.create_message(msg.channel_id, improperly_formatted(cmd))
    end
  end

  def summon(_cmd, msg) do
    case get_voice_channel_of_msg(msg) do
      nil ->
        Api.create_message(msg.channel_id, "Must be in a voice channel to summon")

      voice_channel_id ->
        Voice.join_channel(msg.guild_id, voice_channel_id)
        unless Queues.get_queue(msg.guild_id),
          do: Queues.set_queue(msg.guild_id, :queue.new())
    end
  end

  def leave(_cmd, msg) do
    Voice.leave_channel(msg.guild_id)
    Queues.remove_queue(msg.guild_id)
  end

  def stop(_cmd, msg) do
    ActiveStates.set_active(msg.guild_id, false)
    ActiveStates.set_playing(msg.guild_id, nil)
    Queues.set_queue(msg.guild_id, :queue.new())
    Voice.stop(msg.guild_id)
  end

  def pause(_cmd, msg) do
    ActiveStates.set_active(msg.guild_id, false)
    Voice.pause(msg.guild_id)
  end

  def resume(_cmd, msg) do
    ActiveStates.set_active(msg.guild_id, true)
    Voice.resume(msg.guild_id)
  end

  def skip(_cmd, msg) do
    matches = Regex.named_captures(~r/^#{@prefix}\s*(?<cmd>skip)(\s+(?<num>\d+))?/i, msg.content)
    num = case Integer.parse(matches["num"]) do
      :error -> 1
      {num, _} -> num |> max(1)
    end

    q =
      msg.guild_id
      |> Queues.get_queue
      |> :queue.to_list
      |> Enum.drop(num - 1)
      |> :queue.from_list()

    Queues.set_queue(msg.guild_id, q)

    ActiveStates.set_active(msg.guild_id, false)
    Voice.stop(msg.guild_id)
    trigger_play(msg.guild_id)
    ActiveStates.set_active(msg.guild_id, true)
  end

  def show(_cmd, msg) do
    matches = Regex.named_captures(~r/^#{@prefix}\s*(?<cmd>show)(\s+(?<num>\d+))?/i, msg.content)
    num = case Integer.parse(matches["num"]) do
      :error -> 5
      {num, _} -> num |> max(0)
    end

    playing = case ActiveStates.get_playing(msg.guild_id) do
      nil -> ""
      input -> "Now playing: #{input}\n"
    end

    Api.create_message(msg.channel_id, playing <> peak_queue(msg.guild_id, num))
  end

  def enqueue_url(guild_id, input, type, options) do
    q = Queues.get_queue(guild_id)
    if :queue.len(q) == 0, do: ActiveStates.set_active(guild_id, true)
    q = :queue.in({input, type, options}, q)
    Queues.set_queue(guild_id, q)
    unless Voice.playing?(guild_id), do: trigger_play(guild_id)
  end

  def trigger_play(guild_id) do
    q = Queues.get_queue(guild_id)
    case :queue.out(q) do
      {{:value, {input, type, options}}, q} ->
        Logger.debug("Playing next track #{input}")
        ActiveStates.set_playing(guild_id, input)
        Queues.set_queue(guild_id, q)
        Voice.play(guild_id, input, type, options)

      {:empty, _q} ->
        Logger.debug("DJ Bot Queue Empty for #{guild_id}")
        ActiveStates.set_playing(guild_id, nil)
    end
  end

  def peak_queue(guild_id, num_to_show \\ 5) do
    guild_id
    |> Queues.get_queue
    |> :queue.to_list
    |> Enum.take(num_to_show)
    |> Enum.reduce({1, ""}, fn x, acc ->
      {num, message} = acc
      {input, _, _} = x
      {num + 1, message <> "#{num}: #{input}\n"}
    end)
    |> elem(1)
  end

  def get_voice_channel_of_msg(msg) do
    msg.guild_id
    |> Nostrum.Cache.GuildCache.get!()
    |> Map.get(:voice_states)
    |> Enum.find(%{}, fn v -> v.user_id == msg.author.id end)
    |> Map.get(:channel_id)
  end

  def parse_args(args) do
    case String.split(args, ~r/\s+/, parts: 3) do
      [flag, arg, rest] ->
        case parse_option(flag, arg) do
          :error -> [error: :error]
          :url -> [input: args]
          opt -> opt ++ parse_args(rest)
        end

      _ -> [input: args]
    end
  end

  def parse_option(flag, arg) do
    case flag do
      "-r" -> [realtime: Regex.match?(~r/true/i, arg)]
      "-s" -> [start_pos: arg]
      "-d" -> [duration: arg]
      "-f" -> [filter: arg]
      "-v" ->
        {num, _} = Float.parse(arg)
        [volume: num]
      "-" <> _ -> :error
      _url -> :url
    end
  end

  def get_audio_files(path) do
    path
    |> File.ls!
    |> Stream.map(&("#{path}/#{&1}"))
    |> Stream.flat_map(fn f -> if File.dir?(f), do: get_audio_files(f), else: [f] end)
    |> Stream.filter(&Regex.match?(~r/\.(mp3|m4a|wav|aiff|flac|ogg|aac|wma)$/i, &1))
    |> Enum.shuffle()
  end

  defp improperly_formatted(cmd), do: "Improperly formatted. Usage: #{@prefix}#{@commands |> Map.get(String.downcase(cmd)) |> elem(2)}"
end

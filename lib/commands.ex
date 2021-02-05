defmodule Djbot.Commands do

  alias Djbot.{ActiveStates, Queues}
  alias Nostrum.{Api, Voice}

  require Logger

  @prefix "~"

  @commands %{
    "help"      => {&__MODULE__.help/2, "Show all commands", "help"},
    "play"      => {&__MODULE__.play/2, "Play (or queue) URLs from common service", "play [-r true|false] [-s {START_TIME}] [-d {DURATION}] [-v {VOLUME}] [-f {FILTER}] {URL}"},
    "playfile"  => {&__MODULE__.play/2, "Play (or queue) files from URL", "playfile [-r true|false] [-s {START_TIME}] [-d {DURATION}] [-v {VOLUME}] [-f {FILTER}] {FILE_URL}"},
    "stop"      => {&__MODULE__.stop/2, "Stop the currently playing sound and empty queue", "stop"},
    "pause"     => {&__MODULE__.pause/2, "Pause the currently playing sound", "pause"},
    "resume"    => {&__MODULE__.resume/2, "Resume the currently paused sound", "resume"},
    "skip"      => {&__MODULE__.skip/2, "Skip to next queued track", "skip"},
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
        options = parse_args(matches["args"])
        Logger.debug("Options: #{inspect(options)}")
        if Keyword.get(options, :error), do: raise "Error"
        enqueue_url(msg.guild_id, options, type)
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
    ActiveStates.set_state(msg.guild_id, false)
    Queues.set_queue(msg.guild_id, :queue.new())
    Voice.stop(msg.guild_id)
  end

  def pause(_cmd, msg) do
    ActiveStates.set_state(msg.guild_id, false)
    Voice.pause(msg.guild_id)
  end

  def resume(_cmd, msg) do
    ActiveStates.set_state(msg.guild_id, true)
    Voice.resume(msg.guild_id)
  end

  def skip(_cmd, msg) do
    if Voice.playing?(msg.guild_id), do: Voice.stop(msg.guild_id)
    trigger_play(msg.guild_id)
  end

  def enqueue_url(guild_id, options, type) do
    q = Queues.get_queue(guild_id)
    if :queue.len(q) == 0, do: ActiveStates.set_state(guild_id, true)
    q = :queue.in({options, type}, q)
    Queues.set_queue(guild_id, q)
    unless Voice.playing?(guild_id), do: trigger_play(guild_id)
  end

  def trigger_play(guild_id) do
    q = Queues.get_queue(guild_id)
    case :queue.out(q) do
      {{:value, {options, type}}, q} ->
        Logger.debug("Playing next track #{options[:input]}")
        Queues.set_queue(guild_id, q)
        Voice.play(guild_id, options[:input], type, options)

      {:empty, _q} ->
        Logger.debug("DJ Bot Queue Empty for #{guild_id}")
    end
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

  defp improperly_formatted(cmd), do: "Improperly formatted. Usage: #{@prefix}#{@commands |> Map.get(String.downcase(cmd)) |> elem(2)}"
end

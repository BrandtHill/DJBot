defmodule Djbot.Commands do

  alias Djbot.{ActiveStates, Queues}
  alias Nostrum.{Api, Voice}

  require Logger

  @prefix "~"

  @commands %{
    "help"      => {&__MODULE__.help/1, "Show all commands", "help"},
    "play"      => {&__MODULE__.play/1, "Play URLs from common service", "play {URL}"},
    "playfile"  => {&__MODULE__.playfile/1, "Play files from URL", "playfile {FILE_URL}"},
    "stop"      => {&__MODULE__.stop/1, "Stop the currently playing sound", "stop"},
    "pause"     => {&__MODULE__.pause/1, "Pause the currently playing sound", "pause"},
    "resume"    => {&__MODULE__.resume/1, "Resume the currently paused sound", "resume"},
    "skip"      => {&__MODULE__.skip/1, "Skip to next queued track", "skip"},
    "summon"    => {&__MODULE__.summon/1, "Make the bot join your voice channel", "summon"},
    "leave"     => {&__MODULE__.leave/1, "Make the bot leave your voice channel", "leave"},
  }

  def command_prefix, do: @prefix

  def dispatch(cmd, msg) do
    case Map.get(@commands, cmd) do
      {function, _, _} -> function.(msg)
      nil -> nil
    end
  end

  def help(msg) do
    content = @commands
    |> Enum.reduce("", fn {cmd, {_, desc, usage}}, acc -> acc <> "#{@prefix}#{cmd} - #{desc} - #{@prefix}#{usage}\n" end)
    Api.create_message(msg.channel_id, content)
  end

  def play(msg) do
    matches = Regex.named_captures(~r/^#{@prefix}\s*(?<command>\w+)\s+(?<url>\S+)/i, msg.content)
    if matches do
      if Voice.ready?(msg.guild_id),
        do: enqueue_url(msg.guild_id, matches["url"], :ytdl),
        else: Api.create_message(msg.channel_id, "I must be summoned to a voice channel before playing.")
    else
      Api.create_message(msg.channel_id, improperly_formatted("play"))
    end
  end

  def playfile(msg) do
    matches = Regex.named_captures(~r/^#{@prefix}\s*(?<command>\w+)\s+(?<url>.+)/i, msg.content)
    if matches do
      if Voice.ready?(msg.guild_id),
        do: enqueue_url(msg.guild_id, matches["url"], :url),
        else: Api.create_message(msg.channel_id, "I must be summoned to a voice channel before playing.")
    else
      Api.create_message(msg.channel_id, improperly_formatted("playfile"))
    end
  end

  def summon(msg) do
    case get_voice_channel_of_msg(msg) do
      nil ->
        Api.create_message(msg.channel_id, "Must be in a voice channel to summon")

      voice_channel_id ->
        Voice.join_channel(msg.guild_id, voice_channel_id)
        unless Queues.get_queue(msg.guild_id),
          do: Queues.set_queue(msg.guild_id, :queue.new())
    end
  end

  def leave(msg) do
    Voice.leave_channel(msg.guild_id)
    Queues.remove_queue(msg.guild_id)
  end

  def stop(msg) do
    ActiveStates.set_state(msg.guild_id, false)
    Queues.set_queue(msg.guild_id, :queue.new())
    Voice.stop(msg.guild_id)
  end

  def pause(msg) do
    ActiveStates.set_state(msg.guild_id, false)
    Voice.pause(msg.guild_id)
  end

  def resume(msg) do
    ActiveStates.set_state(msg.guild_id, true)
    Voice.resume(msg.guild_id)
  end

  def skip(msg) do
    if Voice.playing?(msg.guild_id), do: Voice.stop(msg.guild_id)

    trigger_play(msg.guild_id)
  end
  def enqueue_url(guild_id, url, type) do
    q = Queues.get_queue(guild_id)
    if :queue.len(q) == 0, do: ActiveStates.set_state(guild_id, true)
    q = :queue.in({url, type}, q)
    Queues.set_queue(guild_id, q)
    unless Voice.playing?(guild_id), do: trigger_play(guild_id)
  end

  def trigger_play(guild_id) do
    q = Queues.get_queue(guild_id)
    case :queue.out(q) do
      {{:value, {url, type}}, q} ->
        Logger.debug("Playing next track #{url}")
        Queues.set_queue(guild_id, q)
        Voice.play(guild_id, url, type)

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

  defp improperly_formatted(cmd), do: "Improperly formatted. Usage: #{@prefix}#{@commands |> Map.get(String.downcase(cmd)) |> elem(2)}"
end

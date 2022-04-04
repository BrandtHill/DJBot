defmodule Djbot.VoiceCommands do
  alias Djbot.Commands

  require Logger

  @regex_funcs [
    {~r/dj\s+play/i, :play},
    {~r/dj\s+(leave|get out|go away)/i, :leave},
    {~r/dj\s+stop/i, :stop},
    {~r/dj\s+(pause|pies|paws)/i, :pause},
    {~r/dj\s+resume/i, :resume},
    {~r/dj\s+skip/i, :skip}
  ]

  def parse_speech(guild_id, string) do
    Enum.each(@regex_funcs, fn {regex, func} ->
      if Regex.match?(regex, string) do
        Logger.info("Voice command triggered: `#{func}/1` from speech string: #{string}")
        :erlang.apply(__MODULE__, func, [guild_id])
      end
    end)
  end

  def play(guild_id) do
    %{
      guild_id: guild_id,
      data: %{
        name: "playdir",
        options: [
          %{
            name: "url",
            value: "/mus/Gorillaz"
          }
        ]
      }
    }
    |> Commands.play()
  end

  def leave(guild_id) do
    %{guild_id: guild_id}
    |> Commands.leave()
  end

  def stop(guild_id) do
    %{guild_id: guild_id}
    |> Commands.stop()
  end

  def pause(guild_id) do
    %{guild_id: guild_id}
    |> Commands.pause()
  end

  def resume(guild_id) do
    %{guild_id: guild_id}
    |> Commands.resume()
  end

  def skip(guild_id) do
    %{
      guild_id: guild_id,
      data: %{
        options: [
          %{
            name: "amount",
            value: 1
          }
        ]
      }
    }
    |> Commands.skip()
  end
end

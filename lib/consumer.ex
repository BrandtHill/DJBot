defmodule Djbot.Consumer do

  require Logger
  use Nostrum.Consumer
  alias Djbot.{ActiveStates, Commands}
  alias Nostrum.Struct.Event.SpeakingUpdate

  def start_link, do: Consumer.start_link(__MODULE__)

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    unless msg.author.bot do
      #Logger.debug(inspect(msg, pretty: true))
      if matches = Regex.run(~r/^#{Commands.command_prefix}\s*([\w-]+)/, msg.content) do
        matches
        |> Enum.at(1)
        |> Commands.dispatch(msg)
      end
    end
  end

  def handle_event({:VOICE_SPEAKING_UPDATE, %SpeakingUpdate{} = update, _ws_state}) do
    Logger.debug(inspect(update))
    if ActiveStates.get_active(update.guild_id) and not update.speaking, do: Commands.trigger_play(update.guild_id)
  end

  def handle_event(_event) do
    :noop
  end

end

defmodule Djbot.Consumer do
  require Logger

  use Nostrum.Consumer

  alias Djbot.{ActiveStates, Commands, ListeningQueues}
  alias Nostrum.Api
  alias Nostrum.Struct.Event.SpeakingUpdate
  alias Nostrum.Struct.Event.VoiceReady
  alias Nostrum.Voice

  def start_link, do: Consumer.start_link(__MODULE__)

  def handle_event({:READY, _event, _ws_state}) do
    {:ok, commands} = Api.get_global_application_commands()
    registered_commands = Enum.map(commands, fn x -> x.name end)
    all_commands = Commands.commands() |> Map.keys()

    (all_commands -- registered_commands)
    |> Enum.each(fn name ->
      {_, description, options} = Commands.commands()[name]

      Logger.debug("Creating global command: #{name}")

      Api.create_global_application_command(%{
        name: name,
        description: description,
        options: options
      })
    end)
  end

  def handle_event({:VOICE_SPEAKING_UPDATE, %SpeakingUpdate{} = update, _ws_state}) do
    Logger.debug(inspect(update, pretty: true))

    if ActiveStates.get_active(update.guild_id) and not update.speaking,
      do: Commands.trigger_play(update.guild_id)
  end

  def handle_event({:VOICE_READY, %VoiceReady{guild_id: guild_id} = _event, _v_ws_state}) do
    ListeningQueues.create_guild(guild_id)
    Voice.start_listen_async(guild_id)
  end

  def handle_event({:VOICE_INCOMING_PACKET, packet, %{guild_id: guild_id} = _v_ws_state}) do
    # IO.puts "Received packet: #{inspect(elem(packet, 0))}"
    ListeningQueues.enqueue_voice(guild_id, packet)
  end

  def handle_event(
        {:VOICE_STATE_UPDATE, %{guild_id: guild_id, channel_id: nil, user_id: user_id}, _ws_state}
      ) do
    if user_id == Nostrum.Cache.Me.get().id do
      "Bot leaving #{guild_id}"
      ListeningQueues.remove_guild(guild_id)
    end
  end

  def handle_event({:INTERACTION_CREATE, interaction, _ws_state}) do
    # IO.inspect(p)
    response = Commands.dispatch(interaction)
    response = if is_binary(response), do: response, else: "Done - #{Commands.checkmark_emoji()}"
    Api.create_interaction_response(interaction, %{type: 4, data: %{content: response}})
  end

  def handle_event(_), do: :noop
end

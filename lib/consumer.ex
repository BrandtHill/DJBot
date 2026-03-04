defmodule Djbot.Consumer do
  require Logger

  @behaviour Nostrum.Consumer

  alias Djbot.ActiveStates
  alias Djbot.Commands
  alias Djbot.ListeningQueues
  alias Nostrum.Api.Interaction
  alias Nostrum.Api.ApplicationCommand
  alias Nostrum.Struct.Event.SpeakingUpdate
  alias Nostrum.Struct.Event.VoiceReady
  alias Nostrum.Voice

  def handle_event({:READY, _event, _ws_state}) do
    {:ok, commands} = ApplicationCommand.global_commands()
    registered_commands = Enum.map(commands, fn x -> x.name end)
    all_commands = Commands.commands() |> Map.keys()

    (all_commands -- registered_commands)
    |> Enum.each(fn name ->
      {_, description, options} = Commands.commands()[name]

      Logger.debug("Creating global command: #{name}")

      ApplicationCommand.create_global_command(%{
        name: name,
        description: description,
        options: options
      })
    end)
  end

  def handle_event({:VOICE_SPEAKING_UPDATE, %SpeakingUpdate{} = update, _ws_state}) do
    Logger.debug(inspect(update, pretty: true))

    if not update.speaking, do: Commands.delete_playing_message(update.guild_id)

    if ActiveStates.is_active?(update.guild_id) and not update.speaking do
      Commands.trigger_play(update.guild_id)
    end
  end

  def handle_event({:VOICE_READY, %VoiceReady{guild_id: guild_id} = _event, _v_ws_state}) do
    ListeningQueues.create_guild(guild_id)
    Voice.start_listen_async(guild_id)
  end

  def handle_event({:VOICE_INCOMING_PACKET, packet, %{guild_id: guild_id} = _v_ws_state}) do
    ListeningQueues.enqueue_voice(guild_id, packet)
  end

  def handle_event(
        {:VOICE_STATE_UPDATE, %{guild_id: guild_id, channel_id: nil, user_id: user_id}, _ws_state}
      ) do
    if user_id == Nostrum.Cache.Me.get().id do
      Commands.delete_playing_message(guild_id)
      ListeningQueues.remove_guild(guild_id)
    end
  end

  def handle_event({:INTERACTION_CREATE, interaction, _ws_state}) do
    case Commands.dispatch(interaction) do
      {:msg, msg} ->
        reply_with_message(interaction, msg)

      {:msg_after, func, msg} ->
        reply_with_message_after(interaction, func, msg)

      {:embeds, embeds} ->
        reply_with_embeds(interaction, embeds)

      {:components, components} ->
        reply_with_components(interaction, components)

      :empty ->
        reply_with_empty(interaction)
    end
  end

  def handle_event(_), do: :noop

  defp reply_with_message(interaction, msg) do
    Interaction.create_response(interaction, %{type: 4, data: %{content: msg}})
  end

  defp reply_with_embeds(interaction, embeds) do
    Interaction.create_response(interaction, %{type: 4, data: %{embeds: embeds}})
  end

  defp reply_with_components(interaction, components) do
    Interaction.create_response(interaction, %{type: 4, data: %{components: components}})
  end

  defp reply_with_message_after(interaction, func, msg) do
    Interaction.create_response(interaction, %{type: 5})
    func.()
    Interaction.edit_response(interaction, %{content: msg})
  end

  defp reply_with_empty(interaction) do
    Interaction.create_response(interaction, %{type: 6})
  end
end

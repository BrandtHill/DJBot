defmodule Djbot do
  @moduledoc """
  Application entrypoint for `Djbot`.
  """

  use Application

  def start(_type, _args) do
    Djbot.Soundboard.setup_table()

    children = [
      {Nostrum.Bot,
       %{
         wrapped_token: fn -> Application.get_env(:djbot, :discord_api_key) end,
         name: DJBot,
         consumer: Djbot.Consumer,
         intents: :nonprivileged
       }},
      Djbot.PlayingQueues,
      Djbot.ActiveStates
      # Djbot.ListeningQueues
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Djbot.Supervisor)
  end
end

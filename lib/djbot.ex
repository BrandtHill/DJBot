defmodule Djbot do
  @moduledoc """
  Application entrypoint for `Djbot`.
  """

  use Application
  def start(_type, _args) do
    children = [
      Djbot.Consumer,
      Djbot.Queues,
      Djbot.ActiveStates
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Djbot.Supervisor)
  end
end

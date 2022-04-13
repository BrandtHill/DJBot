defmodule Djbot do
  @moduledoc """
  Application entrypoint for `Djbot`.
  """

  use Application

  def start(_type, _args) do
    Djbot.Soundboard.setup_table()

    children =
      for id <- 1..System.schedulers_online(),
          do: Supervisor.child_spec({Djbot.Consumer, []}, id: id)

    children =
      children ++
        [
          Djbot.PlayingQueues,
          Djbot.ActiveStates,
          Djbot.ListeningQueues
        ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Djbot.Supervisor)
  end
end

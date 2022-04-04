defmodule Djbot.PlayingQueues do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

  def get_queue(guild_id), do: GenServer.call(__MODULE__, {:get, guild_id})

  def set_queue(guild_id, queue), do: GenServer.call(__MODULE__, {:set, guild_id, queue})

  def remove_queue(guild_id), do: GenServer.cast(__MODULE__, {:remove, guild_id})

  def handle_call({:get, guild_id}, _from, state), do: {:reply, Map.get(state, guild_id), state}

  def handle_call({:set, guild_id, queue}, _from, state),
    do: {:reply, queue, Map.put(state, guild_id, queue)}

  def handle_cast({:remove, guild_id}, state), do: {:noreply, Map.delete(state, guild_id)}
end

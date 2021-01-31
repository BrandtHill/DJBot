defmodule Djbot.ActiveStates do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

  def get_state(guild_id), do: GenServer.call(__MODULE__, {:get, guild_id})

  def set_state(guild_id, active?), do: GenServer.call(__MODULE__, {:set, guild_id, active?})

  def handle_call({:get, guild_id}, _from, state), do: {:reply, Map.get(state, guild_id, false), state}

  def handle_call({:set, guild_id, active?}, _from, state), do: {:reply, active?, Map.put(state, guild_id, active?)}

end

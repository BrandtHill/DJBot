defmodule Djbot.ActiveStates do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

  def get_active(guild_id), do: GenServer.call(__MODULE__, {:get, guild_id}) |> elem(0)

  def get_playing(guild_id), do: GenServer.call(__MODULE__, {:get, guild_id}) |> elem(1)

  def set_active(guild_id, active?),
    do: GenServer.call(__MODULE__, {:set_state, guild_id, active?})

  def set_playing(guild_id, playing),
    do: GenServer.call(__MODULE__, {:set_playing, guild_id, playing})

  def handle_call({:get, guild_id}, _from, state),
    do: {:reply, Map.get(state, guild_id, {false, nil}), state}

  def handle_call({:set_state, guild_id, active?}, _from, state) do
    {_, playing} = Map.get(state, guild_id, {false, nil})
    {:reply, active?, Map.put(state, guild_id, {active?, playing})}
  end

  def handle_call({:set_playing, guild_id, playing}, _from, state) do
    {active?, _} = Map.get(state, guild_id, {false, nil})
    {:reply, playing, Map.put(state, guild_id, {active?, playing})}
  end
end

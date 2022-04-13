defmodule Djbot.ActiveStates do
  use GenServer

  alias __MODULE__, as: AS

  defmodule State do
    defstruct [:last_msg, :channel_id, :current_url, :active]

    def new(), do: %State{}
    def update(%State{} = state, key, value), do: Map.put(state, key, value)
  end

  def start_link(_opts) do
    GenServer.start_link(AS, %{}, name: AS)
  end

  def init(state) do
    {:ok, state}
  end

  def is_active?(guild_id), do: !!get(guild_id).active
  def get_last_msg(guild_id), do: get(guild_id).last_msg
  def get_current_url(guild_id), do: get(guild_id).current_url
  def get_channel_id(guild_id), do: get(guild_id).channel_id

  def set_active(guild_id, active?), do: set(guild_id, :active, active?)
  def set_last_msg(guild_id, msg), do: set(guild_id, :last_msg, msg)
  def set_current_url(guild_id, url), do: set(guild_id, :current_url, url)
  def set_channel_id(guild_id, channel_id), do: set(guild_id, :channel_id, channel_id)

  defp get(g), do: GenServer.call(AS, {:get, g})
  defp set(g, k, v), do: GenServer.call(AS, {:set, g, k, v})

  def handle_call({:get, guild_id}, _from, map) do
    {:reply, map[guild_id] || State.new(), map}
  end

  def handle_call({:set, guild_id, key, value}, _from, map) do
    state = State.update(map[guild_id] || State.new(), key, value)
    {:reply, state, Map.put(map, guild_id, state)}
  end
end

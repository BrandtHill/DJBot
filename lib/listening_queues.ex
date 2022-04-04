defmodule Djbot.ListeningQueues do
  use GenServer

  alias Djbot.VoiceCommands

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, {%{}, %{}}, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

  def create_guild(guild_id) do
    GenServer.cast(__MODULE__, {:create, guild_id})
  end

  def remove_guild(guild_id) do
    GenServer.cast(__MODULE__, {:remove, guild_id})
  end

  def enqueue_voice(guild_id, packet) do
    GenServer.cast(__MODULE__, {:enqueue, guild_id, packet})
  end

  def handle_cast({:create, guild_id}, {guilds, ports}) do
    guild_state = %{
      q: :queue.new(),
      timer: nil,
      port:
        Port.open({:spawn_executable, System.find_executable("python3")}, [
          {:args, ["-u", File.cwd!() <> "/vosk/test_stdin.py"]},
          :binary,
          :exit_status,
          :use_stdio,
          :stream,
          :stderr_to_stdout
        ])
    }

    guilds = Map.put(guilds, guild_id, guild_state)
    ports = Map.put(ports, guild_state.port, guild_id)

    {:noreply, {guilds, ports}}
  end

  def handle_cast({:remove, guild_id}, {guilds, ports}) do
    port = guilds[guild_id][:port]
    is_nil(port) || Port.close(port)

    ports = Map.delete(ports, port)
    guilds = Map.delete(guilds, guild_id)

    {:noreply, {guilds, ports}}
  end

  def handle_cast({:enqueue, guild_id, packet}, {guilds, ports}) do
    guild_state = guilds[guild_id]

    if is_reference(guild_state.timer), do: Process.cancel_timer(guild_state.timer)

    guild_state =
      Map.put(guild_state, :timer, Process.send_after(self(), {:silence, guild_id}, 100))

    q = :queue.in(packet, guild_state.q)

    q =
      if :queue.len(q) >= 50,
        do: send_q_to_port(guild_state.port, q),
        else: q

    guild_state = Map.put(guild_state, :q, q)
    guilds = Map.put(guilds, guild_id, guild_state)
    {:noreply, {guilds, ports}}
  end

  def handle_info({port, {:data, data}}, {guilds, ports}) do
    guild_id = ports[port]

    Task.start(fn -> VoiceCommands.parse_speech(guild_id, data) end)

    IO.puts(data)

    {:noreply, {guilds, ports}}
  end

  def handle_info({:silence, guild_id}, {guilds, ports}) do
    guilds =
      case guilds[guild_id] do
        nil ->
          guilds

        guild_state ->
          q = send_q_to_port(guild_state.port, guild_state.q, 100)
          guild_state = Map.put(guild_state, :q, q)
          Map.put(guilds, guild_id, guild_state)
      end

    {:noreply, {guilds, ports}}
  end

  def send_q_to_port(port, q, silence \\ 0) do
    (case(:queue.peek(q)) do
       {:value, {{_, _, ssrc}, _opus}} ->
         q
         |> :queue.to_list()
         |> Enum.filter(fn {{_, _, s}, _} -> s == ssrc end)
         |> Nostrum.Voice.pad_opus()

       :empty ->
         []
     end ++
       Nostrum.Voice.Opus.generate_silence(silence))
    |> Nostrum.Voice.create_ogg_bitstream()
    |> then(&Port.command(port, &1))

    :queue.new()
  end
end

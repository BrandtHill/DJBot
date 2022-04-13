defmodule Djbot.Soundboard do
  @table_name :soundboard

  alias Nostrum.Voice.Audio
  alias Nostrum.Voice.Ports

  def setup_table do
    :dets.open_file(@table_name, type: :bag)
    :ets.new(@table_name, [:named_table, :public, :bag])
    :ets.from_dets(@table_name, @table_name)
    :dets.close(@table_name)
  end

  def add_sound(guild_id, name, url, type \\ :ytdl) do
    delete_sound(guild_id, name)
    raw_frames = encode_audio(url, type)
    :ets.insert(@table_name, {guild_id, name, raw_frames})
    sync_table_to_disk()
  end

  def get_sound(guild_id, name) do
    case :ets.match(@table_name, {guild_id, name, :"$1"}) do
      [] -> nil
      [[frames]] -> frames
    end
  end

  def get_sound_names(guild_id) do
    :ets.match(@table_name, {guild_id, :"$1", :_})
    |> List.flatten()
  end

  def delete_sound(guild_id, name) do
    :ets.match_delete(@table_name, {guild_id, name, :_})
    sync_table_to_disk()
  end

  defp sync_table_to_disk do
    :dets.open_file(@table_name, type: :bag)
    :ets.to_dets(@table_name, @table_name)
    :dets.close(@table_name)
  end

  defp encode_audio(url, type) do
    pid = Audio.spawn_ffmpeg(url, type, realtime: false)
    {:ok, timer} = :timer.apply_after(5_000, Ports, :close, [pid])

    Enum.map_reduce(Ports.get_stream(pid), timer, fn p, t ->
      :timer.cancel(t)
      {:ok, t} = :timer.apply_after(2_500, Ports, :close, [pid])
      {p, t}
    end)
    |> elem(0)
  end
end

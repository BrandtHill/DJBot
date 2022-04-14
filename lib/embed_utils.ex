defmodule Djbot.EmbedUtils do
  alias Djbot.Commands
  alias Djbot.ActiveStates
  alias Nostrum.Struct.Embed
  alias Nostrum.Voice
  import Embed

  @youtube_regex ~r/(https?\:\/\/)?((www\.)?youtube\.com|youtu\.be)/
  @soundcloud_regex ~r/(https?\:\/\/)?((www\.)?soundcloud\.com)/
  @file_regex ~r/^\/.+\.(mp3|m4a|wav|aiff|flac|ogg|aac|wma)$/i
  @f_exts ~r/\.(mp3|m4a|wav|aiff|flac|ogg|aac|wma)$/i
  @youtube_oembed "https://youtube.com/oembed?url="
  @soundcloud_oembed "https://soundcloud.com/oembed?format=json&url="
  @headers [{"Accepts", "application/json"}]

  def get_metadata(url) do
    cond do
      Regex.match?(@youtube_regex, url) -> do_oembed_request(@youtube_oembed, url)
      Regex.match?(@soundcloud_regex, url) -> do_oembed_request(@soundcloud_oembed, url)
      Regex.match?(@file_regex, url) -> do_ffprobe(url)
      true -> nil
    end
  end

  def do_ffprobe(url) do
    with {out, 0} <- System.cmd("ffprobe", [url | ~w(-v quiet -print_format json -show_format)]),
         {:ok, json} <- Jason.decode(out),
         tags <- json["format"]["tags"] do
      {:ffprobe, tags}
    else
      _ -> nil
    end
  end

  def title_from_ffprobe(url, tags) do
    title =
      tags["title"] ||
        String.split(url, "/") |> List.last() |> String.replace(@f_exts, "")

    artist = tags["artist"] || tags["album_artist"] || tags["TSO2"] || nil

    artist = if artist, do: "#{artist} - ", else: ""
    artist <> title
  end

  def do_oembed_request(oembed_url, url) do
    with {:ok, %HTTPoison.Response{status_code: 200, body: body}} <-
           HTTPoison.get(oembed_url <> url, @headers, recv_timeout: 2_000),
         {:ok, json} <- Jason.decode(body) do
      {:oembed, json}
    else
      _ -> nil
    end
  end

  def create_now_playing_embed(guild_id) do
    case ActiveStates.get_current_url(guild_id) do
      nil ->
        %Embed{}
        |> put_color(0xFF7733)
        |> put_field("DJ Bot", "Nothing currently playing")

      url ->
        msg = (Voice.playing?(guild_id) && "Now playing") || "Paused"

        embed =
          %Embed{}
          |> put_color(0x6633EE)
          |> put_field(msg, url, true)

        case get_metadata(url) do
          nil ->
            embed

          {:ffprobe, tags} when is_map(tags) ->
            put_title(embed, title_from_ffprobe(url, tags))

          {:oembed, oembed} when is_map(oembed) ->
            embed
            |> put_author(oembed["author_name"], oembed["author_url"], oembed["thumbnail_url"])
            |> put_provider(oembed["provider_name"], oembed["provider_url"])
            |> put_thumbnail(oembed["thumbnail_url"])
            |> put_title(oembed["title"])
            |> put_url(url)
        end
    end
  end

  @spec create_up_next_embed(any) :: any
  def create_up_next_embed(urls) do
    embed =
      %Embed{}
      |> put_color(0xAA00FF)
      |> put_title("DJ Bot Up Next")

    urls
    |> Task.async_stream(&get_metadata/1)
    |> Stream.map(fn
      {:ok, res} -> res
      _ -> nil
    end)
    |> Stream.zip(urls)
    |> Stream.with_index(1)
    |> Enum.reduce(embed, fn {{oembed, url}, i}, embed ->
      case oembed do
        {:oembed, %{"title" => title}} ->
          put_field(embed, "#{i}:\t#{title}", url)

        {:ffprobe, tags} ->
          put_field(embed, "#{i}:\t#{title_from_ffprobe(url, tags)}", url)

        nil ->
          put_field(embed, "#{i}:\t#{Commands.rand_emoji()}", url)
      end
    end)
  end
end

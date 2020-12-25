defmodule Downloader do
  require Logger

  @moduledoc """
  GenServer used to download files from a blind test song list
  """
  alias Nostrum.Api

  defmodule Yydl do
    @moduledoc """
    Ytdl is a simple module used to try and retry youtube-dl command
    """

    # fake UA, use Internet Explorer 7
    @user_agent "Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.0)"

    @max_retry 5
    @timer 1 * 1000

    def get(url), do: get(url, 0)

    def get(url, @max_retry),
      do: {:error, "Error getting #{url}, after #{@max_retry} retries"}

    def get(url, retries) do
      Logger.info("Getting Youtube data URL", url: url, retries: retries)

      if retries != 0 do
        IO.inspect(retries)
        :timer.sleep(@timer)
      end

      case System.cmd("youtube-dl", [
             "--user-agent",
             @user_agent,
             "-g",
             "-f",
             "bestaudio",
             url
           ]) do
        {stdout, 0} ->
          {:ok, stdout}

        {_stderr, _code} ->
          get(url, retries + 1)
      end
    end
  end

  defmodule Worker do
    use GenServer

    def start_link(stack) do
      GenServer.start_link(__MODULE__, stack, name: __MODULE__)
    end

    @moduledoc """
    Worker module downloading files
    """
    def init({songs, cache, channel_id, private_channel_id}) do
      Logger.info("Starting Downloader worker", data: songs)

      # create cache directory if needed
      case File.mkdir_p(cache) do
        {:error, reason} ->
          Api.create_message(
            channel_id,
            "__Downloader status update__: cache directory creation failed, all downloads aborted"
          )

          {:stop, reason}

        :ok ->
          {:ok, {songs, cache, channel_id, private_channel_id}, {:continue, :work}}
      end
    end

    def handle_continue(:work, {[], _cache, channel_id, private_channel_id}) do
      for channel <- [channel_id, private_channel_id] do
        Api.create_message(
          channel,
          "__Downloader status update__: all songs in cache"
        )
      end

      case BlindTest.process() do
        {:one, _} ->
          Game.set_ready()

        :none ->
          Api.create_message(channel_id, "Error when communicating with blind test process")
      end

      Logger.info("Downloader worker exits")

      {:stop, :normal, []}
    end

    def handle_continue(:work, {[current | rest], cache, channel_id, private_channel_id}) do
      Logger.info("Downloader worker, work in progress", current: current, data: rest)

      with {:one, _} = BlindTest.process(),
           {:ok, uuid} <- Youtube.parse_uuid(current.url),
           {:ok, ts} <- Youtube.get_timestamp(current.url),
           {:ok, stdout} <- Yydl.get(current.url) do
        case String.split(stdout, "\n") do
          [] ->
            Api.create_message(
              private_channel_id,
              "__Downloader status update__: no data found for url #{current.url}"
            )

          [data_url | _] ->
            start =
              Timex.Duration.to_time!(%Timex.Duration{
                microseconds: 0,
                megaseconds: 0,
                seconds: ts
              })

            to =
              Timex.Duration.to_time!(%Timex.Duration{
                microseconds: 0,
                megaseconds: 0,
                seconds: ts + 50
              })

            case System.cmd("ffmpeg", [
                   "-y",
                   "-ss",
                   Time.to_string(start),
                   "-to",
                   Time.to_string(to),
                   "-i",
                   data_url,
                   "-c:a",
                   "libopus",
                   "-ac",
                   "1",
                   "-b:a",
                   "96K",
                   "-vbr",
                   "on",
                   "-frame_duration",
                   "20",
                   "#{cache}/#{uuid}.opus"
                 ]) do
              {_stdout, 0} ->
                {:ok, :added} = Game.add_guess(current)

              {_stderr, _} ->
                Api.create_message(
                  private_channel_id,
                  "__Downloader status update__: error getting raw data for url #{current.url}"
                )
            end
        end
      else
        {:none} ->
          Api.create_message(
            private_channel_id,
            "__Downloader status update__: error when communicating with blind test process"
          )

        {:error, reason} ->
          Api.create_message(
            private_channel_id,
            reason
          )
      end

      if length(rest) > 0 do
        for channel <- [channel_id, private_channel_id] do
          Api.create_message(
            channel,
            "__Downloader status update__: download in progress, #{length(rest)} song(s) remaining"
          )
        end
      end

      {:noreply, {rest, cache, channel_id, private_channel_id}, {:continue, :work}}
    end
  end
end

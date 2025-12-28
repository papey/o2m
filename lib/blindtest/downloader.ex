defmodule Downloader do
  @moduledoc """
  GenServer used to download files from a blind test song list
  """

  require Logger

  alias Nostrum.Api

  def parse_timestamps(ts, guess_duration) do
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
        seconds: ts + trunc(guess_duration * 1.5)
      })

    {:ok, start, to}
  end

  defmodule Yydl do
    @moduledoc """
    Ytdl is a simple module used to try and retry yt-dlp command
    """

    @max_retry 3
    @timer 1 * 200

    defmodule DownloadData do
      defstruct [
        :url,
        :data_url,
        :ts_from,
        :ts_to,
        :output,
        check: false
      ]
    end

    defmodule Ffmpeg do
      def args(dl_data),
        do: dl_data |> base_args() |> add_check_args(dl_data) |> add_file_arg(dl_data)

      defp base_args(dl_data) do
        [
          "-y",
          "-ss",
          Time.to_string(dl_data.ts_from),
          "-to",
          Time.to_string(dl_data.ts_to),
          "-i",
          dl_data.data_url,
          "-c:a",
          "libopus",
          "-ac",
          "1",
          "-b:a",
          "96K",
          "-vbr",
          "on",
          "-frame_duration",
          "20"
        ]
      end

      defp add_check_args(args, %DownloadData{check: check}) when check,
        do: args ++ ["-f", "null"]

      defp add_check_args(args, _), do: args

      defp add_file_arg(args, %DownloadData{output: file}), do: args ++ [file]
    end

    def get_url(url), do: get_url(url, 0)

    def get_url(url, @max_retry),
      do: {:error, "Error getting #{url}, after #{@max_retry} retries"}

    def get_url(url, retries) do
      Logger.info("Getting Youtube data URL", url: url, retries: retries)

      if retries != 0 do
        :timer.sleep(@timer)
      end

      System.cmd("yt-dlp", ["--rm-cache-dir"])

      case System.cmd("yt-dlp", [
             "--youtube-skip-dash-manifest",
             "--hls-prefer-native",
             "-g",
             "-f",
             "bestaudio",
             url
           ]) do
        {stdout, 0} ->
          {:ok, String.trim(stdout)}

        {_stderr, _code} ->
          get_url(url, retries + 1)
      end
    end

    def get_data(%DownloadData{} = dl_data),
      do: get_data(dl_data, 0)

    def get_data(%DownloadData{data_url: url}, @max_retry),
      do: {:error, "unable to download url `#{url}`"}

    def get_data(%DownloadData{} = dl_data, retries) do
      if retries != 0 do
        :timer.sleep(@timer)
      end

      case System.cmd("ffmpeg", Ffmpeg.args(dl_data)) do
        {_stdout, 0} ->
          {:ok}

        {_stderr, _} ->
          case get_url(dl_data.url) do
            {:ok, new_data_url} ->
              %DownloadData{dl_data | data_url: new_data_url} |> get_data(retries + 1)

            error ->
              error
          end
      end
    end
  end

  defmodule Worker do
    @moduledoc """
    Worker module downloading files
    """

    use GenServer

    def start_link(stack) do
      IO.inspect(stack)
      GenServer.start_link(__MODULE__, stack, name: __MODULE__)
    end

    def init({songs, cache, channel_id, _private_channel_id, _guess_duration} = stack) do
      Logger.info("Starting Downloader worker", data: songs)

      # create cache directory if needed
      case File.mkdir_p(cache) do
        {:error, reason} ->
          Api.Message.create(
            channel_id,
            "__Downloader status update__: cache directory creation failed, downloads aborted"
          )

          {:stop, reason}

        :ok ->
          {:ok, stack, {:continue, :work}}
      end
    end

    def handle_continue(:work, {[], _cache, channel_id, private_channel_id, _guess_duration}) do
      for channel <- [channel_id, private_channel_id] do
        Api.Message.create(
          channel,
          "__Downloader status update__: all songs in cache"
        )
      end

      if BlindTest.exists?() do
        Game.set_ready()
      else
        Api.Message.create(channel_id, "Error when communicating with blind test process")
      end

      {:stop, :normal, []}
    end

    def handle_continue(
          :work,
          {[current | rest], cache, channel_id, private_channel_id, guess_duration}
        ) do
      Logger.info("Downloader worker, work in progress", current: current, data: rest)

      with {:ok} = BlindTest.ensure_running(),
           {:ok, uuid} <- Youtube.parse_uuid(current.url),
           {:ok, ts} <- Youtube.get_timestamp(current.url),
           {:ok, start, to} <- Downloader.parse_timestamps(ts, guess_duration),
           {:ok, data_url} <- Yydl.get_url(current.url),
           {:ok} <-
             Yydl.get_data(%Yydl.DownloadData{
               data_url: data_url,
               url: current.url,
               ts_from: start,
               ts_to: to,
               output: "#{cache}/#{uuid}.opus",
               check: false
             }) do
        Game.add_guess(current)
      else
        {:error, reason} ->
          Api.Message.create(
            private_channel_id,
            "__Downloader status update__: error when downloading #{current.url}, reason : #{reason}"
          )
      end

      if length(rest) > 0 do
        for channel <- [channel_id, private_channel_id] do
          Api.Message.create(
            channel,
            "__Downloader status update__: download in progress, #{length(rest)} song(s) remaining"
          )
        end
      end

      {:noreply, {rest, cache, channel_id, private_channel_id, guess_duration},
       {:continue, :work}}
    end
  end
end

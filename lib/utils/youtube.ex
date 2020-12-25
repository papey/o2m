defmodule Youtube do
  @moduledoc """
  Utils used for Youtube stuff
  """

  @doc """
  Parses a YouTube UUID

  Return ok with UUID if found, error with reason otherwise

  ## Examples
      iex> Youtube.parse_uuid("https://www.youtube.com/watch?v=toGFQM12JSw")
      {:ok, "toGFQM12JSw"}
      iex> Youtube.parse_uuid("https://youtu.be/K1Bzo6SdS3c?t=39")
      {:ok, "K1Bzo6SdS3c"}
  """
  def parse_uuid(url) do
    uri = URI.parse(url)

    cond do
      uri.path == "/watch" ->
        params = URI.decode_query(uri.query)

        case Map.get(params, "v", :none) do
          :none -> {:error, "No uuid found"}
          some -> {:ok, some}
        end

      uri.host == "youtu.be" ->
        {:ok, String.trim_leading(uri.path, "/")}

      true ->
        {:error, "Not a valid youtube url"}
    end
  end

  @doc """
  Parse a timestamp from YouTube url

  Returns timestamp or 0 if none found

  ## Examples
    iex> Youtube.get_timestamp("https://youtu.be/K1Bzo6SdS3c?t=97")
    {:ok, 97}
  """
  def get_timestamp(url) do
    uri = URI.parse(url)

    if uri.query do
      params = URI.decode_query(uri.query)

      if Map.has_key?(params, "t") do
        case Integer.parse(Map.get(params, "t")) do
          {seconds, _} ->
            {:ok, seconds}

          :error ->
            {:error, "Not a valid timestamp"}
        end
      else
        {:ok, 0}
      end
    else
      {:ok, 0}
    end
  end
end

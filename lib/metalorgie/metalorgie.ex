defmodule Metalorgie do
  @moduledoc """
  A simple Elixir module used to talk with https://www.metalorgie.com
  """

  @doc """
  Get metalorgie url from `config.exs`

  Returns `https://www.metalorgie.com`.

  ## Examples

      iex> Metalorgie.get_config_url()
      "https://www.metalorgie.com"

  """
  def get_config_url() do
    {:ok, url} = Application.fetch_env(:o2m, :metalorgie)
    url
  end

  @doc """
  Get json data for a specific band from Metalorgie

  Returns ok + `json object` or error + message
  """
  def get_band(band) do
    # Concat string, but before apply a downcase operation on all list members
    terms =
      band
      |> Enum.map(fn e -> String.downcase(e) end)

    match = Enum.join(terms, " ")

    # HTTP get call
    resp =
      Tesla.get!(
        Metalorgie.get_config_url() <>
          "/api/band.php" <>
          "?filter=[%7B\"property\":\"name\",\"value\":\"#{Enum.join(terms, "%20")}\"%7D]"
      )

    # Decode json
    {:ok, json} = Jason.decode(resp.body)

    # Filter on band name, hard search
    filter = Enum.filter(json, fn e -> String.downcase(e["name"]) == match end)

    # If a band is found
    case filter do
      [band | _] ->
        {:ok, band}

      _ ->
        # if not
        # Filter on band name, soft search
        filter =
          Enum.filter(json, fn e -> String.contains?(String.downcase(e["name"]), terms) end)

        # If a band is found
        case filter do
          [band | _] -> {:ok, band}
          _ -> {:error, "No band with name **#{Enum.join(band, " ")}** found"}
        end
    end
  end

  @doc """
  Get json data for a specific album from Metalorgie

  Returns ok + `json object` or error + message
  """
  def get_album(artist, album) do
    # First get band data
    case get_band(artist) do
      {:ok, data} ->
        # Album title
        album = Enum.join(album, " ")

        # Filter albums by name
        filtered =
          Enum.filter(data["discography"], fn e ->
            String.contains?(String.downcase(e["name"]), String.downcase(album))
          end)

        case filtered do
          [album | _] ->
            {:ok, album}

          _ ->
            {:error, "No album named **#{album}** found for artist **#{Enum.join(artist, " ")}**"}
        end

      {:error, message} ->
        {:error, message}
    end
  end

  @doc """
  Forge a band url from a slug

  Returns formatted url containing band slug

  ## Examples

      iex> Metalorgie.forge_band_url("korn")
      "https://www.metalorgie.com/groupe/korn"
  """
  def forge_band_url(slug) do
    Metalorgie.get_config_url() <> "/groupe/" <> slug
  end

  @doc """
  Forge an album url from a band, album name and album id

  Returns formatted url containing album slug

  ## Examples
      iex> Metalorgie.forge_album_url("korn", "the nothing", "31745")
      "https://www.metalorgie.com/groupe/korn/31745_the-nothing"
  """
  def forge_album_url(band, album, id) do
    "#{Metalorgie.get_config_url()}/groupe/#{slug_term(band)}/#{id}_#{slug_term(album)}"
  end

  defp slug_term(term) do
    term
    |> String.replace(":", "")
    |> String.replace(" ", "-")
  end
end

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
  Get data for a specific band from Metalorgie

  Returns ok + map or error + message
  """
  def get_band(band) do
    terms =
      band
      |> Enum.map(fn e -> String.downcase(e) end)

    resp =
      HTTPoison.get!(
        Metalorgie.get_config_url() <>
          "/api/bands" <>
          "?name=#{Enum.join(terms, "%20")}"
      )

    {:ok, json} =
      Jason.decode(resp.body)

    case json do
      %{"bands" => [%{"url" => url, "shortDescription" => desc, "id" => id} | _]} ->
        {:ok, %{url: url, desc: desc, id: id}}

      _ ->
        {:error, "No band with name **#{Enum.join(band, " ")}** found"}
    end
  end

  @doc """
  Get albums data for a specific band from Metalorgie

  Returns ok + map or error + message
  """
  def get_albums(band) do
    case get_band(band) do
      {:ok, %{id: id}} ->
        resp =
          HTTPoison.get!(
            Metalorgie.get_config_url() <>
              "/api/albums" <>
              "?band=#{id}"
          )

        {:ok, json} =
          Jason.decode(resp.body)

        case json do
          %{"albums" => albums} ->
            {:ok,
             Enum.map(albums, fn album ->
               %{title: album["title"], url: album["url"], year: album["year"]}
             end)}

          _ ->
            {:error, "No album found for band **#{band}**"}
        end

      {:error, message} ->
        {:error, message}
    end
  end
end

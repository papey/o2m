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

  def api_key_setup?() do
    match?({:ok, _}, get_api_key())
  end

  def get_api_key() do
    case System.get_env("METALORGIE_MASTER_API_KEY") do
      key when is_binary(key) and key != "" -> {:ok, key}
      _ -> {:error, "No API key setup"}
    end
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

  @doc """
  Submit a news proposal to Metalorgie

  Returns `{:ok, response}` or `{:error, reason}`
  """
  def submit_news(text, source, name) do
    with {:ok, api_key} <- get_api_key(),
         {:ok, body} <-
           Jason.encode(%{
             text: text,
             source: source,
             name: name,
             proposalSource: "discord"
           }),
         {:ok, %HTTPoison.Response{status_code: code, body: resp_body}} when code in 200..299 <-
           HTTPoison.post(
             Metalorgie.get_config_url() <> "/api/news",
             body,
             [
               {"X-AUTH-TOKEN", api_key},
               {"Content-Type", "application/json"}
             ]
           ) do
      case Jason.decode(resp_body) do
        {:ok, json} -> {:ok, json}
        {:error, _} -> {:ok, resp_body}
      end
    else
      {:ok, %HTTPoison.Response{status_code: code, body: resp_body}} ->
        {:error, {:http_error, code, resp_body}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}

      {:error, _} = error ->
        error
    end
  end
end

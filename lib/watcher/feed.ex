defmodule Feed do
  @moduledoc """
  A simple module used to get information about a podcast
  """

  require Logger

  @doc """
  Get last episode data from a show using RSS feed

  Returns a tuple containing date, title and url of last episode
  """
  def get_last_episode(url) do
    # Get rss feed
    url
    |> HTTPoison.get()
    |> handle_resp(url)
  end

  defp handle_resp({:ok, resp}, _url) when resp.status_code == 200 do
    {:ok, xml} = ElixirFeedParser.parse(resp.body)

    # Get last episode
    [last | _] = xml.entries

    # Return needed data
    %{date: last.updated, title: last.title, url: last.url, show: xml.title}
  end

  defp handle_resp({:ok, resp}, _url) do
    Logger.error("Received non 200 (ok) HTTP status code, sending :nodata atom",
      code: resp.status
    )

    :nodata
  end

  defp handle_resp({:error, reason}, url) do
    Logger.error("Error getting last episode", url: url, reason: reason)
    :nodata
  end

  @doc """
  Forge a new message including show details

  Returns a string presenting the new show
  """
  def new_message(show) do
    Announcements.announce(%{
      "show" => show.show,
      "title" => show.title,
      "url" => show.url
    })
  end
end

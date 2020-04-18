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
    HTTPoison.start()

    # Get rss feed
    case HTTPoison.get(url) do
      {:ok, resp} ->
        case resp.status_code do
          200 ->
            # Parse feed
            xml = ElixirFeedParser.parse(resp.body)

            # Get last episode
            [last | _] = xml.entries

            # Return needed data
            %{date: last.updated, title: last.title, url: last.url, show: xml.title}

          _ ->
            Logger.error("Received non 200 (ok) HTTP status code, sending :nodata atom",
              code: resp.status_code
            )

            :nodata
        end

      {:error, message} ->
        Logger.error("Error getting last episode", url: url, reason: message)
        :nodata
    end
  end

  @doc """
  Compare to dates, is the second one is after the first one return `true` else return `false`

  Returns `true` or `false`

  ## Examples

      iex> Feed.compare_dates("Tue, 15 Oct 2019 15:00:00 +0000", "Wed, 16 Oct 2019 15:00:00 +0000")
      -1
  """
  def compare_dates(cur, next) do
    # Anchor dates contains GMT
    case String.contains?(cur, "GMT") && String.contains?(next, "GMT") do
      true ->
        # This is an Anchor podcast, parse it using Anchor syntax
        cur = Timex.parse!(cur, "%a, %d %b %Y %H:%M:%S GMT", :strftime)
        next = Timex.parse!(next, "%a, %d %b %Y %H:%M:%S GMT", :strftime)
        Timex.compare(cur, next)

      false ->
        # This is a Ausha podcast, parse it using Ausha syntax
        cur = Timex.parse!(cur, "%a, %d %b %Y %H:%M:%S %z", :strftime)
        next = Timex.parse!(next, "%a, %d %b %Y %H:%M:%S %z", :strftime)
        Timex.compare(cur, next)
    end
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

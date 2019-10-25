defmodule Ausha do
  @moduledoc """
  A simple module used to get information about a podcast on Ausha https://podcast.ausha.co
  """

  @doc """
  Get last episode data from a show on Ausha using a slug

  Returns a tuple containing date, title and url of last episode
  """
  def get_last_episode(slug) do
    HTTPoison.start()

    # Get rss feed
    resp = HTTPoison.get!("https://feed.ausha.co/" <> slug)

    # Parse feed
    xml = ElixirFeedParser.parse(resp.body)

    # Get last episode
    last = Enum.at(xml.entries, 0)

    # Return needed data
    %{date: last.updated, title: last.title, url: last.url, show: xml.title}
  end

  @doc """
  Compare to dates, is the second one is after the first one return `true` else return `false`

  Returns `true` or `false`

  ## Examples

      iex> Ausha.compare_dates("Tue, 15 Oct 2019 15:00:00 +0000", "Wed, 16 Oct 2019 15:00:00 +0000")
      true
  """
  def compare_dates(cur, next) do
    cur = Timex.parse!(cur, "%a, %d %b %Y %H:%M:%S %z", :strftime)
    next = Timex.parse!(next, "%a, %d %b %Y %H:%M:%S %z", :strftime)

    cur < next
  end

  @doc """
  Forge a new message including show details

  Returns a string presenting the new show
  """
  def new_message(show) do
    "A new show for #{show.show} was published ! Check out \"#{show.title}\" at #{show.url}"
  end
end

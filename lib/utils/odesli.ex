defmodule Odesli do
  @api_version "v1-alpha.1"
  @base_url "https://api.song.link"
  @links_url "#{@base_url}/#{@api_version}/links"

  @platforms ["spotify", "deezer", "appleMusic", "youtube", "bandcamp", "tidal"]

  defmodule Response do
    defstruct [:artist, :title, :urls]
  end

  def get(url) do
    {:ok, resp} = HTTPoison.get("#{@links_url}?#{URI.encode_query(%{url: url})}")

    case resp do
      %HTTPoison.Response{status_code: 200} ->
        parsed = Jason.decode!(resp.body)

        meta = parsed["entitiesByUniqueId"] |> Map.values() |> List.first()

        {:ok,
         %Response{
           artist: meta["artistName"],
           title: meta["title"],
           urls: plateform_urls(parsed)
         }}

      _ ->
        {:error, :no_match}
    end
  end

  defp plateform_urls(%{"linksByPlatform" => links}) do
    Enum.reduce(@platforms, %{}, fn plt, acc ->
      link = links[plt]["url"]

      if link do
        Map.put(acc, plt, link)
      else
        acc
      end
    end)
  end
end

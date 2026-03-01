defmodule StreamingFinder do
  alias Nostrum.Api.Message

  @url_regex ~r/(https?:\/\/[^\s]+)/i
  @max_urls 3

  def handle(reaction) do
    with {:ok, origin} <- Message.get(reaction.channel_id, reaction.message_id) do
      case extract_urls(origin.content) do
        [] ->
          react_fuck(origin)

        urls ->
          urls
          |> Enum.take(@max_urls)
          |> Enum.each(&process_url(&1, origin))
      end
    end
  end

  defp process_url(url, origin) do
    if QLink.qobuz?(url), do: process_qobuz(url, origin), else: process_generic(url, origin)
  end

  defp process_qobuz(url, origin) do
    case QLink.convert(url) do
      {:ok, odesli_url} ->
        reply([{:songlink, odesli_url}], origin)

      _ ->
        react_shrug(origin)
    end
  end

  def process_generic(url, origin) do
    case Odesli.get(url) do
      {:ok, odesli_url} ->
        [songlink: odesli_url]
        |> enrich_with_qobuz_url(odesli_url)
        |> reply(origin)

      {:error, _} ->
        react_shrug(origin)
    end
  end

  defp enrich_with_qobuz_url(links, odesli_url) do
    with {:ok, %{body: body}} <- HTTPoison.get(odesli_url),
         {:ok, spotify} <- Odesli.extract_spotify_url(body),
         {:ok, qobuz} <- QLink.convert(spotify) do
      links ++ [qobuz: qobuz]
    else
      _ -> links
    end
  end

  defp react_shrug(origin), do: Discord.react(origin, "🤷")
  defp react_fuck(origin), do: Discord.react(origin, "🖕")

  defp reply(links, origin),
    do:
      Message.create(origin.channel_id,
        content: format_links(links),
        message_reference: %{message_id: origin.id}
      )

  defp format_links(links) do
    links
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn
      {:songlink, url} -> "[Songlink](#{url})"
      {:qobuz, url} -> "[Qobuz](#{url})"
      {_, url} -> "[Link](#{url})"
    end)
    |> Enum.join(" - ")
  end

  defp extract_urls(content) do
    Regex.scan(@url_regex, content)
    |> List.flatten()
    |> Enum.uniq()
  end
end

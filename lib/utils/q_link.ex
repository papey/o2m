defmodule QLink do
  import Meeseeks.CSS

  @base_url "https://qlink.fyi"
  @convert_path "/convert?url="

  @timeout 30_000

  @qobuz_prefixes ["https://www.qobuz.com/", "https://open.qobuz.com"]

  def convert(nil), do: {:error, :link_not_found}
  def convert(url), do: prepare_url(url) |> request_conversion |> extract_link

  def qobuz?(url),
    do: Enum.any?(@qobuz_prefixes, fn prefix -> String.starts_with?(url, prefix) end)

  defp request_conversion(url) do
    full_query = "#{@base_url}#{@convert_path}#{URI.encode_www_form(url)}"

    case HTTPoison.get(full_query,
           timeout: @timeout,
           recv_timeout: @timeout
         ) do
      {:ok, %{status_code: 200, body: body}} -> {:ok, body}
      {:ok, %{status_code: code}} -> {:error, "Server status #{code}"}
      {:error, %{reason: reason}} -> {:error, reason}
    end
  end

  defp extract_link({:error, _} = error), do: error

  defp extract_link({:ok, body}) do
    body
    |> Meeseeks.parse(:html)
    |> Meeseeks.one(css("a.linkresult"))
    |> case do
      nil -> {:error, :link_not_found}
      element -> {:ok, Meeseeks.attr(element, "href")}
    end
  end

  defp prepare_url(url) do
    regex = ~r{(https://www.qobuz.com/.*/(?:album|track)/).*/([^/]+)$}

    case Regex.run(regex, url) do
      [_, base, id] -> base <> id
      _ -> url
    end
  end
end

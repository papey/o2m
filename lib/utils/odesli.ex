defmodule Odesli do
  import Meeseeks.CSS

  @base_url "https://api.odesli.co/resolve"
  @timeout 30_000

  def get(url) do
    case HTTPoison.get(@base_url, [],
           params: %{url: url},
           timeout: @timeout,
           recv_timeout: @timeout
         ) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        decode_response(body)

      {:ok, %HTTPoison.Response{status_code: code}} ->
        {:error, {:http_error, code}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp decode_response(body) do
    case Jason.decode(body) do
      {:ok, %{"id" => id, "type" => type, "provider" => provider}} ->
        {:ok, build_odesli_url(id, type, provider)}

      {:ok, _} ->
        {:error, :unexpected_payload}

      {:error, _} ->
        {:error, :invalid_json}
    end
  end

  def extract_spotify_url(html) do
    result =
      html
      |> Meeseeks.parse()
      |> Meeseeks.one(css("a[href*='spotify.com']"))

    case result do
      nil -> {:error, :link_not_found}
      node -> {:ok, Meeseeks.attr(node, "href")}
    end
  end

  defp build_odesli_url(id, type, provider) do
    "https://#{type}.link/#{String.first(provider)}/#{id}"
  end
end

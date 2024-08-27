defmodule Odesli do
  @base_url "https://api.odesli.co"
  @resolve_path "resolve"

  @timeout 30_000

  defmodule Response do
    defstruct [:type, :id, :provider]
  end

  def get(url) do
    {:ok, resp} =
      HTTPoison.get("#{@base_url}/#{@resolve_path}?#{URI.encode_query(%{url: url})}", [],
        timeout: @timeout,
        recv_timeout: @timeout
      )

    case resp do
      %HTTPoison.Response{status_code: 200} ->
        parsed = Jason.decode!(resp.body)

        {:ok,
         %Response{
           id: parsed["id"],
           type: parsed["type"],
           provider: parsed["provider"]
         }}

      _ ->
        {:error, :no_match}
    end
  end
end

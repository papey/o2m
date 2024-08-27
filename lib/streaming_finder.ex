defmodule StreamingFinder do
  @url_regex ~r/(https?:\/\/[^\s]+)/i
  @max_urls 3

  def handle(reaction) do
    {:ok, origin} = Nostrum.Api.get_channel_message(reaction.channel_id, reaction.message_id)

    case extract_urls(origin.content) do
      [] ->
        Nostrum.Api.create_reaction(origin.channel_id, origin.id, "🖕")

      urls ->
        for url <- urls |> Enum.take(@max_urls) do
          case Odesli.get(url) do
            {:ok, %Odesli.Response{id: id, type: type, provider: provider}} ->
              Nostrum.Api.create_message(
                origin.channel_id,
                content: message(type, id, provider),
                message_reference: %{message_id: origin.id}
              )

            {:error, :no_match} ->
              Nostrum.Api.create_reaction(origin.channel_id, origin.id, "🤷")
          end
        end
    end
  end

  defp message(type, id, provider) do
    "https://#{type}.link/#{String.first(provider)}/#{id}"
  end

  defp extract_urls(content) do
    Regex.scan(@url_regex, content)
    |> List.flatten()
    |> Enum.uniq()
  end
end

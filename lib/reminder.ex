defmodule Reminder do
  import Discord

  @max 500

  def remind(reaction) do
    {:ok, dm} = Nostrum.Api.create_dm(reaction.user_id)

    with {:ok, _chan} <- is_chan_public(reaction.channel_id),
         {:ok, origin} <-
           Nostrum.Api.get_channel_message(reaction.channel_id, reaction.message_id) do
      content =
        if origin.content != "",
          do: String.slice(origin.content, 0..@max),
          else: "__No text content found__"

      Nostrum.Api.create_message(dm.id,
        embed: %Nostrum.Struct.Embed{
          :title => " 🧠 Here is your reminder !",
          :description => "from channel #{channel(reaction.channel_id)}",
          :fields => [
            %Nostrum.Struct.Embed.Field{
              name: "Content",
              value: content
            },
            %Nostrum.Struct.Embed.Field{
              name: "Attachments",
              value: "#{length(origin.attachments)} file(s)"
            },
            %Nostrum.Struct.Embed.Field{
              name: "Link",
              value:
                "https://discord.com/channels/#{reaction.guild_id}/#{reaction.channel_id}/#{reaction.message_id}"
            }
          ]
        }
      )
    else
      {:error, reason} ->
        Nostrum.Api.create_message(dm.id, "**Error**: _#{reason}_")
    end
  end
end

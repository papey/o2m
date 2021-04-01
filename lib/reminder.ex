defmodule Reminder do
  import Discord

  def remind(reaction) do
    max = 500
    {:ok, dm} = Nostrum.Api.create_dm(reaction.user_id)

    with :public <- channel_type(reaction.channel_id),
         {:ok, origin} <-
           Nostrum.Api.get_channel_message(reaction.channel_id, reaction.message_id) do
      url =
        "https://discord.com/channels/#{reaction.guild_id}/#{reaction.channel_id}/#{
          reaction.message_id
        }"

      content =
        if String.length(origin.content) >= max,
          do: "#{String.slice(origin.content, 0..(max - 1))}…",
          else: origin.content

      fields = [
        %Nostrum.Struct.Embed.Field{
          name: "Content",
          value: content
        },
        %Nostrum.Struct.Embed.Field{
          name: "Link",
          value: url
        }
      ]

      Nostrum.Api.create_message(dm.id,
        embed: %Nostrum.Struct.Embed{
          :title => " 🧠 Here is your reminder !",
          :description => "from channel #{channel(reaction.channel_id)}",
          :fields => fields
        }
      )
    else
      {:error, reason} ->
        Nostrum.Api.create_message(dm.id, "Error, #{reason}")

      :private ->
        Nostrum.Api.create_reaction(reaction.channel_id, reaction.message_id, "🖕")
    end
  end
end

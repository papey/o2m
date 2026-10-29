defmodule O2M do
  @moduledoc """
  A simple Elixir module based on Nostrum to interact with Discord
  """
  alias O2M.Config
  alias Nostrum.Struct.Interaction
  require Logger

  # This is a Nostrum Consumer
  @behaviour Nostrum.Consumer

  @doc """
  Handle events from Discord
  """
  def handle_event({:READY, _data, _ws_state}) do
    if Metalorgie.api_key_setup?() do
      O2M.Commands.slash_commands_definitions()
      |> Enum.map(fn command ->
        Nostrum.Api.ApplicationCommand.create_guild_command(Config.get(:guild), command)
      end)
    end
  end

  def handle_event(
        {:INTERACTION_CREATE,
         %Interaction{
           member: %{nick: nick},
           data: %{
             name: "submit_news",
             options: options
           },
           user: %{global_name: global_name, username: username}
         } = interaction, _ws_state}
      ) do
    %{"text" => text, "source" => source} = Map.new(options, &{&1.name, &1.value})

    content =
      case Metalorgie.submit_news(text, source, nick || global_name || username) do
        {:ok, _} ->
          "✅ News submitted"

        {:error, reason} ->
          Logger.error("Failed to submit news: #{inspect(reason)}")
          "❌ Error submitting news"
      end

    Nostrum.Api.Interaction.create_response(interaction, %{type: 4, data: %{content: content}})
  end

  def handle_event({:MESSAGE_REACTION_ADD, reaction, _ws_state}), do: handle_reaction(reaction)

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) when msg.author.bot, do: :ignore

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    msg
    |> add_command_context(Config.get(:prefix))
    |> handle_message()
  end

  # Default event handler, if you don't include this, your consumer WILL crash if
  # you don't have a method definition for each event type.
  def handle_event(_event) do
    :noop
  end

  def add_command_context(msg, prefix) do
    if String.starts_with?(msg.content, prefix) do
      {:cmd, msg, prefix}
    else
      {:msg, msg}
    end
  end

  def handle_message({:cmd, msg, prefix}), do: O2M.Commands.handle_message(msg, prefix)

  def handle_message({:msg, msg}) when msg.content == "", do: :ignore

  def handle_message({:msg, msg}),
    do: BlindTest.handle_message(msg, Config.get(:bt_chan))

  def handle_reaction(reaction) do
    case reaction.emoji.name do
      "📌" -> Reminder.remind(reaction)
      "👀" -> Reminder.delete(reaction)
      "🔗" -> StreamingFinder.handle(reaction)
      _ -> :ignore
    end
  end
end

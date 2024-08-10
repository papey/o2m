defmodule O2M do
  @moduledoc """
  A simple Elixir module based on Nostrum to interact with Discord
  """
  alias O2M.Config

  # This is a Nostrum Consumer
  use Nostrum.Consumer

  @doc """
  Basic start and setup of the Nostrum consumer
  """
  def start_link() do
    # Start Consumer
    Consumer.start_link(__MODULE__)
  end

  @doc """
  Handle events from Discord
  """
  def handle_event({:MESSAGE_REACTION_ADD, reaction, _ws_state}), do: handle_reaction(reaction)

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) when msg.author.bot, do: :ignore

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    msg
    |> enrich_message(Config.get(:prefix))
    |> handle_message()
  end

  # Default event handler, if you don't include this, your consumer WILL crash if
  # you don't have a method definition for each event type.
  def handle_event(_event) do
    :noop
  end

  def enrich_message(msg, prefix) do
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

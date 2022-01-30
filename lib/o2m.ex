defmodule O2M do
  @moduledoc """
  A simple Elixir module based on Nostrum to interact with Discord
  """

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
    # fetch prefix
    {:ok, prefix} = Application.fetch_env(:o2m, :prefix)

    msg
    |> enrich_message(prefix)
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
    do: BlindTest.handle_message(msg, O2M.Application.from_env_to_int(:o2m, :bt_chan))

  def handle_reaction(reaction) do
    case reaction.emoji.name do
      "📌" ->
        Reminder.remind(reaction)

      "👀" ->
        with {:ok, origin} <-
               Nostrum.Api.get_channel_message(reaction.channel_id, reaction.message_id),
             {:ok, _chan} <- Discord.is_chan_private(origin.channel_id),
             true <- origin.author.bot,
             {:ok} <- Nostrum.Api.delete_message(reaction.channel_id, reaction.message_id) do
        else
          {:error, reason} ->
            Nostrum.Api.create_message(reaction.channel_id, "**Error**: _#{reason}_")

          _ ->
            :ignore
        end

      _ ->
        :ignore
    end
  end
end

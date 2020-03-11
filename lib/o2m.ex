defmodule O2M do
  @moduledoc """
  A simple Elixir module based on Nostrum to interact with Discord
  """

  # This is a Nostrum Consumer
  use Nostrum.Consumer
  alias Nostrum.Api

  @doc """
  Basic start and setup of the Nostrum consumer
  """
  def start_link() do
    # Start Consumer
    pid = Consumer.start_link(__MODULE__)
    # Change username
    {:ok, val} = Application.fetch_env(:o2m, :username)
    Api.modify_current_user(username: val)
    # Return pid
    pid
  end

  @doc """
  Handle events from Discord
  """
  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    # fetch username value
    {:ok, username} = Application.fetch_env(:o2m, :username)
    # Ensure this is not the bot talking to itself
    if msg.author.username != username do
      # fetch prefix
      {:ok, prefix} = Application.fetch_env(:o2m, :prefix)

      # Handle commands
      case O2M.Commands.extract_cmd_and_args(msg.content, prefix) do
        # if an error occured while parsing
        {:error, reason} ->
          Api.create_message(msg.channel_id, reason)

        # if command is mo with args and subcommand
        {:ok, "mo", sub, args} ->
          Api.create_message(msg.channel_id, O2M.Commands.Mo.handle(sub, args))

        # if command is help with args and subcommand
        {:ok, "help", _, _} ->
          Api.create_message(msg.channel_id, O2M.Commands.Help.handle(prefix))

        # if a command is not already catch by a case, this is not a supported command
        {:ok, cmd, _, _} ->
          case cmd do
            "" ->
              Api.create_message(
                msg.channel_id,
                "Sorry but I need at least a command to do something"
              )

            _ ->
              Api.create_message(msg.channel_id, "Sorry but **#{cmd}** command is not available")
          end

        # If something goes realy wrong, do not care
        _ ->
          :ignore
      end
    end
  end

  # Default event handler, if you don't include this, your consumer WILL crash if
  # you don't have a method definition for each event type.
  def handle_event(_event) do
    :noop
  end
end

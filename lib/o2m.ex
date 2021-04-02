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
    Consumer.start_link(__MODULE__)
  end

  @doc """
  Handle events from Discord
  """
  def handle_event({:MESSAGE_REACTION_ADD, reaction, _ws_state}) do
    case reaction.emoji.name do
      "📌" ->
        Reminder.remind(reaction)

      "👀" ->
        with {:ok, origin} <-
               Nostrum.Api.get_channel_message(reaction.channel_id, reaction.message_id),
             :private <- Discord.channel_type(origin.channel_id),
             true <- origin.author.bot,
             {:ok} <- Nostrum.Api.delete_message(reaction.channel_id, reaction.message_id) do
        else
          {:error, reason} ->
            Nostrum.Api.create_message(reaction.channel_id, "Error, #{reason}")

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    unless msg.author.bot do
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

        {:ok, "tmpl", sub, args} ->
          Api.create_message(msg.channel_id, O2M.Commands.Tmpl.handle(sub, args))

        # if command is help with args and subcommand
        {:ok, "help", _, _} ->
          Api.create_message(msg.channel_id, O2M.Commands.Help.handle(prefix))

        # if command is blind test
        {:ok, "bt", sub, args} ->
          case BlindTest.configured?() do
            # Sometimes, handle does not return a message since it's heavily use reaction emojis
            true ->
              case O2M.Commands.Bt.handle(sub, args, msg) do
                :no_message ->
                  nil

                message ->
                  Api.create_message(msg.channel_id, message)
              end

            false ->
              Api.create_message(
                msg.channel_id,
                "Sorry but blind test is **not configured** on this Discord Guild 😢"
              )
          end

        # if a command is not already catch by a case, this is not a supported command
        {:ok, cmd, _, _} ->
          case cmd do
            "" ->
              Api.create_message(
                msg.channel_id,
                "Sorry but I need at least **a command** to do something"
              )

            _ ->
              Api.create_message(msg.channel_id, "Sorry but **#{cmd}** ? 🤷")
          end

        # if no command, check if it's from a blind-test channel and if channel is in guessing mode
        _ ->
          case BlindTest.process() do
            :none ->
              :ignore

            {:one, _pid} ->
              channel_id = O2M.Application.from_env_to_int(:o2m, :bt_chan)

              if channel_id == msg.channel_id && msg.content != "" && BlindTest.guessing?() &&
                   BlindTest.plays?(msg.author.id) do
                # validate answer
                case Game.validate(msg.content, msg.author.id) do
                  {:ok, status, points} ->
                    # react to validation
                    BlindTest.react_to_validation(msg, channel_id, status, points)

                  :not_guessing ->
                    :ignore
                end
              else
                :ignore
              end
          end

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

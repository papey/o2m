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
      case extract_cmd_and_args(msg.content, prefix) do
        {"band", args} ->
          Api.create_message(msg.channel_id, band(args))

        {"album", args} ->
          Api.create_message(msg.channel_id, album(args))

        {"help", args} ->
          Api.create_message(msg.channel_id, help(args))

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

  @doc """
  Extract command and args from a message

  Returns a tuple containing cmd and args

  ## Examples

      iex> O2M.extract_cmd_and_args("!band test", "!")
      {"band", ["test"]}

  """
  def extract_cmd_and_args(content, prefix) do
    if String.starts_with?(content, prefix) do
      [cmd | args] = String.split(content, " ")
      {String.replace(cmd, prefix, ""), args}
    end
  end

  # Search for a band
  # If no args provided
  def band([]) do
    "Missing band name for `band` command"
  end

  # If an arg is provided
  def band(args) do
    case Metalorgie.get_band(args) do
      {:ok, band} ->
        Metalorgie.forge_band_url(band["slug"])

      {:error, msg} ->
        msg
    end
  end

  # Search for an album
  # If no args provided
  def album([]) do
    "Missing band name and album name for `album` command"
  end

  # If an arg is provided
  def album(args) do
    [band | album] =
      Enum.join(args, " ") |> String.split("//") |> Enum.map(fn e -> String.trim(e) end)

    case Metalorgie.get_album(String.split(band, " "), String.split(Enum.at(album, 0), " ")) do
      {:ok, album} ->
        Metalorgie.forge_album_url(band, album["name"], album["id"])

      {:error, message} ->
        message
    end
  end

  # Help
  # If no args provided
  def help([]) do
    "Using prefix #{Application.fetch_env!(:o2m, :prefix)}, available commands are :
    - **album**: to get album info
    - **band**: to get page band info
    - **help**: to get this help message"
  end

  # If an arg is provided
  def help(args) do
    case Enum.join(args, " ") do
      "album" ->
        "Here is an example of \`album\` command : \`\`\`#{Application.fetch_env!(:o2m, :prefix)}album korn // follow the leader \`\`\`"

      "band" ->
        "Here is an example of \`band\` command : \`\`\`#{Application.fetch_env!(:o2m, :prefix)}band korn\`\`\`"

      _ ->
        "Command not available"
    end
  end
end

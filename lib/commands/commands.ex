defmodule O2M.Commands do
  require Logger

  @moduledoc """
  Commands module handle routing to all available commands
  """

  @doc """
  Extract command, subcommand and args from a message

  Returns a tuple containing cmd and args

  ## Examples

      iex> O2M.extract_cmd_and_args("!mo band test", "!")
      {:ok, "mo", "band", ["test"]}

  """
  def extract_cmd_and_args(content, prefix) do
    if String.starts_with?(content, prefix) do
      case String.split(content, " ", trim: true) do
        [cmd, sub] ->
          {:ok, String.replace(cmd, prefix, ""), sub, []}

        [cmd, sub | args] ->
          {:ok, String.replace(cmd, prefix, ""), sub, args}

        [cmd] ->
          {:ok, String.replace(cmd, prefix, ""), :none, []}

        _ ->
          {:error, "Error parsing command"}
      end
    end
  end

  defmodule Help do
    @moduledoc """
    Help module handle coll to help command
    """

    def handle(prefix) do
      "**Commands**
Using prefix `#{prefix}` :
- mo : to interact with metalorgie website and database
- tmpl : to interact with announcement templates
- bt : to interact with blind tests (configured: **#{BlindTest.configured?()}**)
- help : to get this help message

**Emojis**
- 📌 : add this emoji as a reaction to pin a public message in order to get a private reminder about the pinned message
- 👀️️ : in your private channel with the bot add this emoji as a reaction to delete a bot message"
    end
  end
end

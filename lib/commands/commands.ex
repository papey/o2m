defmodule O2M.Commands do
  @moduledoc """
  Commands module handle routing to all available commands
  """

  require Logger
  alias Nostrum.Api

  @cmds ["mo", "tmpl", "help", "bt"]

  @handlers %{
    "mo" => &__MODULE__.Mo.handle/3,
    "tmpl" => &__MODULE__.Tmpl.handle/3,
    "help" => &__MODULE__.Help.handle/3,
    "bt" => &__MODULE__.Bt.handle/3
  }
  @doc """
  Extract command, subcommand and args from a message

  Returns a tuple containing cmd and args

  ## Examples

      iex> O2M.extract_cmd_and_args("!mo band test", "!")
      {:ok, "mo", "band", ["test"]}

  """
  def extract_cmd_and_args(content, prefix) do
    case String.split(content, " ", trim: true) do
      [cmd, sub] ->
        {String.replace(cmd, prefix, ""), sub, []}

      [cmd, sub | args] ->
        {String.replace(cmd, prefix, ""), sub, args}

      [cmd] ->
        {String.replace(cmd, prefix, ""), :none, []}
    end
  end

  def handle_message(msg, prefix) do
    {cmd, sub, args} = extract_cmd_and_args(msg.content, prefix)

    cmd
    |> handle_cmd(sub, args, msg)
    |> handle_reply(msg)
  end

  def handle_cmd("", _sub, _args, _msg),
    do: {:error, "Sorry but I need at least **a command** to do something"}

  def handle_cmd(cmd, sub, args, msg) when cmd in @cmds do
    handler_fun = Map.get(@handlers, cmd)

    handler_fun.(sub, args, msg)
  end

  def handle_cmd(cmd, _sub, _args, _msg),
    do: {:error, "Sorry but **#{cmd}** ? 🤷"}

  def handle_reply({:ok, :silent}, _msg), do: :ignore

  def handle_reply({:ok, reply}, msg) do
    Api.Message.create(msg.channel_id,
      content: reply,
      message_reference: %{message_id: msg.id}
    )
  end

  def handle_reply({:error, reason}, msg) do
    Api.Message.create(msg.channel_id,
      content: "**Error**: _#{reason}_",
      message_reference: %{message_id: msg.id}
    )
  end

  defmodule Help do
    @moduledoc """
    Help module handle coll to help command
    """

    def handle(_, _, _) do
      reply = "**Commands**
Using prefix `#{O2M.Config.get(:prefix)}` :
- mo : to interact with metalorgie website and database
- tmpl : to interact with announcement templates
- bt : to interact with blind tests (configured: **#{O2M.Config.get(:bt)}**)
- help : to get this help message

**Emojis**
- 🔗 : find links for all streaming plateforms from the resources linked in the message content
- 📌 : add this emoji as a reaction to pin a public message in order to get a private reminder about the pinned message
- 👀️️ : in your private channel with the bot add this emoji as a reaction to delete a bot message"
      {:ok, reply}
    end
  end
end

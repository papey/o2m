defmodule O2M.Commands.Mo do
  import Metalorgie
  alias O2M.Config

  @moduledoc """
  Mo module handle call to mo command
  """

  @doc """
  Handle Mo commands and route to sub commands
  """
  def handle(sub, args, _) do
    case sub do
      "band" ->
        band(args)

      "albums" ->
        albums(args)

      "help" ->
        help(args)

      "teuton" ->
        {:ok, "https://www.youtube.com/watch?v=WmlshlqXD54"}

      "beluga" ->
        {:ok, "https://www.youtube.com/watch?v=H0WyhJseftI"}

      _ ->
        {:error, "Sorry but subcommand **#{sub}** of command **mo** is not supported"}
    end
  end

  # If no args provided
  def band([]) do
    {:error, "Missing band name for `band` subcommand"}
  end

  @doc """
  Handle band command and search for a band on Metalorgie
  """
  def band(args) do
    case get_band(args) do
      {:ok, %{url: url, desc: desc}} ->
        {:ok, "[#{desc}](#{url})"}

      error ->
        error
    end
  end

  @doc """
  Search for an album from a specified band on Metalorgie
  """
  def albums([]) do
    "Missing band name `albums` subcommand"
  end

  # If args provided
  def albums(args) do
    case get_albums(args) do
      {:ok, albums} ->
        message =
          Enum.map(albums, fn %{title: title, url: url, year: year} -> "[#{title} (#{year})](#{url})" end)
          |> Enum.join(" · ")

        {:ok, message}

      error ->
        error
    end
  end

  @doc """
  Handle help command
  """
  def help([]) do
    reply = "Available **mo** subcommands are :
    **albums**: to get albums (try _#{Config.get(:prefix)}mo help albums_)
    **band**: to get page band (try _#{Config.get(:prefix)}mo help band_)
    **help**: to get this help message"

    {:ok, reply}
  end

  # If an arg is provided
  def help(args) do
    reply =
      case Enum.join(args, " ") do
        "albums" ->
          "Here is an example of \`albums\` subcommand : \`\`\`#{Config.get(:prefix)}mo albums korn\`\`\`"

        "band" ->
          "Here is an example of \`band\` subcommand : \`\`\`#{Config.get(:prefix)}mo band korn\`\`\`"

        sub ->
          "Subcommand #{sub} not available"
      end

    {:ok, reply}
  end
end

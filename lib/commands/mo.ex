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

      "album" ->
        album(args)

      "help" ->
        help(args)

      "teuton" ->
        {:ok, "https://www.youtube.com/watch?v=WmlshlqXD54"}

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
      {:ok, band} ->
        {:ok, forge_band_url(band["slug"])}

      error ->
        error
    end
  end

  @doc """
  Search for an album from a specified band on Metalorgie
  """
  def album([]) do
    "Missing band name and album name for `album` subcommand"
  end

  # If args provided
  def album(args) do
    [band | album] =
      args
      |> Enum.join(" ")
      |> String.split("//")
      |> Enum.map(fn e -> String.trim(e) end)

    case get_album(String.split(band, " "), String.split(Enum.at(album, 0), " ")) do
      {:ok, album} ->
        {:ok, forge_album_url(band, album["name"], album["id"])}

      error ->
        error
    end
  end

  @doc """
  Handle help command
  """
  def help([]) do
    reply = "Available **mo** subcommands are :
    - **album**: to get album info (try _#{Config.get(:prefix)}mo help album_)
    - **band**: to get page band info (try _#{Config.get(:prefix)}mo help band_)
    - **help**: to get this help message"

    {:ok, reply}
  end

  # If an arg is provided
  def help(args) do
    reply =
      case Enum.join(args, " ") do
        "album" ->
          "Here is an example of \`album\` subcommand : \`\`\`#{Config.get(:prefix)}mo album korn // follow the leader \`\`\`"

        "band" ->
          "Here is an example of \`band\` subcommand : \`\`\`#{Config.get(:prefix)}mo band korn\`\`\`"

        sub ->
          "Subcommand #{sub} not available"
      end

    {:ok, reply}
  end
end

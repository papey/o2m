defmodule O2M.Commands.Mo do
  import Metalorgie

  @moduledoc """
  Mo module handle call to mo command
  """

  @doc """
  Handle Mo commands and route to sub commands
  """
  def handle(sub, args) do
    case sub do
      "band" ->
        band(args)

      "album" ->
        album(args)

      "help" ->
        help(args)

      "teuton" ->
        "https://www.youtube.com/watch?v=WmlshlqXD54"

      _ ->
        "Sorry but subcommand **#{sub}** of command **mo** is not supported"
    end
  end

  # If no args provided
  def band([]) do
    "Missing band name for `band` subcommand"
  end

  @doc """
  Handle band command and search for a band on Metalorgie
  """
  def band(args) do
    case get_band(args) do
      {:ok, band} ->
        forge_band_url(band["slug"])

      {:error, msg} ->
        msg
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
        forge_album_url(band, album["name"], album["id"])

      {:error, message} ->
        message
    end
  end

  @doc """
  Handle help command
  """
  def help([]) do
    "Available **mo** subcommands are :
    - **album**: to get album info (try _#{Application.fetch_env!(:o2m, :prefix)}mo help album_)
    - **band**: to get page band info (try _#{Application.fetch_env!(:o2m, :prefix)}mo help band_)
    - **help**: to get this help message"
  end

  # If an arg is provided
  def help(args) do
    case Enum.join(args, " ") do
      "album" ->
        "Here is an example of \`album\` subcommand : \`\`\`#{Application.fetch_env!(:o2m, :prefix)}mo album korn // follow the leader \`\`\`"

      "band" ->
        "Here is an example of \`band\` subcommand : \`\`\`#{Application.fetch_env!(:o2m, :prefix)}mo band korn\`\`\`"

      sub ->
        "Subcommand #{sub} not available"
    end
  end
end
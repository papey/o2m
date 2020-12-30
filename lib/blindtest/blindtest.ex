defmodule BlindTest do
  require Logger

  # playlist max size, makes HolyRilettes happy
  @playlist_size_limit 42

  defmodule GuessEntry do
    @moduledoc """
    Struct representing a blind test guess entry
    """
    defstruct [
      :url,
      artists: [],
      titles: []
    ]
  end

  def check([], _, _), do: "Error no attachements found in this message"

  def check(attachements) do
    with {:ok, file} <- find_songs_attachement(attachements),
         {:ok, resp} <- Tesla.get(file.url),
         {:ok, _guess_entries} <- parse_csv(resp.body) do
      {:ok, file.filename}
    else
      error -> error
    end
  end

  def init([], _, _), do: "Error no attachements found in this message"

  def init(attachements, author, from_channel, args) do
    guild = O2M.Application.from_env_to_int(:o2m, :guild)
    channel_id = O2M.Application.from_env_to_int(:o2m, :bt_chan)
    cache = Application.get_env(:o2m, :bt_cache)

    with {:ok, file} <- find_songs_attachement(attachements),
         {:ok, resp} <- Tesla.get(file.url),
         {:ok, guess_entries} <- parse_csv(resp.body),
         {:ok, _} <-
           Nostrum.Api.create_message(
             from_channel,
             "Blind test init started, using `#{file.filename}` in channel #{
               Discord.channel(channel_id)
             }"
           ) do
      # use provided args and fallback to filename as default
      playlist_name = if args == [], do: file.filename, else: Enum.join(args, " ")

      {:ok, _} =
        Game.start(
          {author.id, guild, channel_id, file.url, playlist_name},
          {guess_entries, cache, channel_id, from_channel}
        )

      "__Download worker started__ : #{length(guess_entries)} song(s) to download"
    else
      {:error, reason} -> "Error #{reason}"
    end
  end

  @doc """
  Use to find attachment file songs.csv in attachements of a message

  Returns file from attachements
  """
  def find_songs_attachement(attachements) do
    case Enum.find(attachements, &(Path.extname(&1.filename) == ".csv")) do
      nil -> {:error, "`.csv` file not found in attachements of this message"}
      file -> {:ok, file}
    end
  end

  @doc """
  Parse the csv file to create guess entries

  Returns all guess entries from this file in a MapSet
  """
  def parse_csv(content) do
    Logger.info("Parsing CSV", data: content)

    String.replace(content, "\r", "")
    |> String.replace(";", ",")
    |> String.split("\n")
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {l, i}, {:ok, acc} ->
      # skips comments and emtpy lines
      if !String.starts_with?(l, "#") and l != "" do
        case String.replace(l, "\"", "") |> String.split(",") do
          [url, artists, titles] ->
            uri = URI.parse(url)

            cond do
              !String.valid?(l) ->
                {:halt,
                 {:error,
                  "Line #{i + 1} contains an invalid character, ensure it contains only UTF-8 characters"}}

              length(acc) > @playlist_size_limit ->
                {:halt, {:error, "Playlist size limit reached #{@playlist_size_limit}"}}

              String.contains?(uri.host, "youtu.be") || String.contains?(uri.host, "youtube") ->
                {:cont,
                 {:ok,
                  acc ++
                    [
                      %GuessEntry{
                        url: url,
                        artists: Enum.map(String.split(artists, "|"), &String.trim(&1)),
                        titles: Enum.map(String.split(titles, "|"), &String.trim(&1))
                      }
                    ]}}

              true ->
                {:halt, {:error, "URL #{url} is not a valid youtube url (line #{i + 1}: `#{l}`)"}}
            end

          _ ->
            {:halt, {:error, "Can't parse line #{i + 1}: `#{l}`"}}
        end
      else
        {:cont, {:ok, acc}}
      end
    end)
  end

  @doc """
  Titleize an input string

  Return titleiized input string

  ## Examples
      iex> BlindTest.titleize("spiritbox rules of nines")
      "Spiritbox Rules Of Nines"
  """
  def titleize(input) do
    String.split(input, " ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")
  end

  @doc """
  Sanitizes inputs from both CSV and answer

  Returns sanitized input

  ## Examples
      iex> BlindTest.sanitize_input("ab'''''c")
      "abc"
  """
  def sanitize_input(input) do
    String.trim(input)
    |> String.replace(~r/[^a-zA-Z0-9 -]/, "")
    |> String.replace(~r/\s+/, " ")
    |> String.downcase()
  end

  @doc """
  Verify if current answer is the artist, the song title or both

  Returns an atom describing the answer status

  ## Examples
      iex> BlindTest.verify_answer(%BlindTest.GuessEntry{artists: ["Spiritbox"], titles: ["Holly Roller"]}, "spiritbox holl roller")
      :both
  """
  def verify_answer(expected, proposal) do
    threshold = 0.2

    valid? =
      &(Levenshtein.distance(sanitize_input(&1), sanitize_input(proposal)) /
          String.length(Enum.max([expected, proposal])) < threshold)

    both_combinations =
      for artist <- expected.artists, title <- expected.titles do
        ["#{artist} #{title}", "#{title} #{artist}"]
      end

    cond do
      Enum.find_value(List.flatten(both_combinations), false, &valid?.(&1)) ->
        :both

      Enum.find_value(expected.artists, false, &valid?.(&1)) ->
        :artist

      Enum.find_value(expected.titles, false, &valid?.(&1)) ->
        :title

      true ->
        :wrong
    end
  end

  @doc """
  React and respond to validate call

  Returns a reaction to an answer
  """
  def react_to_validation(msg, bt_channel_id, status, points) do
    case status do
      :wrong ->
        nil

      :already ->
        # ⏰
        Nostrum.Api.create_reaction(bt_channel_id, msg.id, %Nostrum.Struct.Emoji{
          name: Emojos.get(:already)
        })

      :artist ->
        # 🎤
        Nostrum.Api.create_reaction(bt_channel_id, msg.id, %Nostrum.Struct.Emoji{
          name: Emojos.get(:artist)
        })

        Nostrum.Api.create_message(
          bt_channel_id,
          "#{Discord.mention(msg.author.id)} just found the artist name and earned #{points} points !"
        )

      :title ->
        # 💿
        Nostrum.Api.create_reaction(bt_channel_id, msg.id, %Nostrum.Struct.Emoji{
          name: Emojos.get(:title)
        })

        Nostrum.Api.create_message(
          bt_channel_id,
          "#{Discord.mention(msg.author.id)} just found the song title and earned #{points} points !"
        )

      :both ->
        # 🏆
        Nostrum.Api.create_reaction(bt_channel_id, msg.id, %Nostrum.Struct.Emoji{
          name: Emojos.get(:both)
        })

        Nostrum.Api.create_message(
          bt_channel_id,
          "#{Discord.mention(msg.author.id)} just found both the artist and the song title and earned #{
            points
          } points !"
        )
    end
  end

  @doc """
  Check if a blind test state machine process is currently running

  Returns an atom describing process status
  """
  def process() do
    case Process.whereis(Game) do
      nil -> :none
      pid -> {:one, pid}
    end
  end

  def status() do
    cond do
      Process.whereis(Game) != nil && Process.whereis(Downloader.Worker) != nil ->
        :game_downloading

      Process.whereis(Game) != nil ->
        cond do
          BlindTest.finished?() ->
            :game_finished

          BlindTest.started?() ->
            :game_started

          true ->
            :game_not_started
        end

      true ->
        :none
    end
  end

  @doc """
  Check if current blind test process is in guessing mode

  Returns true if the state of the state machine is guessing, false otherwise
  """
  def guessing?() do
    {:ok, status} = GenStateMachine.call(Game, :guessing?)
    status
  end

  def finished?() do
    {:ok, status} = GenStateMachine.call(Game, :finished?)
    status
  end

  def started?() do
    {:ok, status} = GenStateMachine.call(Game, :started?)
    status
  end

  @doc """
  Check if a user ID is in current blind test players list

  Returns true if player is member, false otherwise
  """
  def plays?(id) do
    {:ok, play} = GenStateMachine.call(Game, {:plays?, id})
    play
  end

  @doc """
  Destroy the current blind test process
  """
  def destroy() do
    guild_id = O2M.Application.from_env_to_int(:o2m, :guild)

    Nostrum.Voice.leave_channel(guild_id)
    # leave the channel
    # kill game process and downloader
    if Process.whereis(Game) != nil do
      Process.whereis(Game) |> Process.exit(:kill)
    end
  end

  @doc """
  Check if blind test is fully configured

  Return true if configured, false otherwise
  """
  def configured?() do
    vars = [:bt_admin, :bt_chan, :bt_vocal]

    configured =
      Enum.take_while(vars, fn var ->
        Application.fetch_env!(:o2m, var) != nil
      end)

    length(vars) == length(configured)
  end
end

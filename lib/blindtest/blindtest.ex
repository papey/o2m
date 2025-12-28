defmodule BlindTest do
  require Logger
  alias Nostrum.Api.Message

  # playlist max size, makes HolyRilettes happy
  @playlist_size_limit 42

  # max len of custom fields
  @max_field_len 100

  # min duration for both song and transition
  @min_duration 1

  defmodule GuessEntry do
    @moduledoc """
    Struct representing a blind test guess entry
    """
    defstruct [
      :url,
      f1s: [],
      f2s: []
    ]
  end

  defmodule Config do
    @moduledoc """
    Struct for a blind test config
    """
    defstruct f1: "artist",
              f2: "title",
              f1_scoring: 2,
              f2_scoring: 3,
              both_scoring: 8,
              guess_duration: 45,
              transition_duration: 15,
              error_threshold: 0.2
  end

  def check([], _, _), do: {:error, "No attachements found in this message"}

  def check(attachements) do
    with {:ok, file} <- find_songs_attachement(attachements),
         {:ok, resp} <- HTTPoison.get(file.url),
         {:ok, {_, guess_entries}} <- parse_csv(resp.body) do
      {:ok, {file.filename, guess_entries}}
    else
      error -> error
    end
  end

  def init([], _, _), do: {:error, "No attachements found in this message"}

  def init(attachements, author, from_channel, args) do
    channel_id = O2M.Config.get(:bt_chan)

    with {:ok, file} <- find_songs_attachement(attachements),
         {:ok, resp} <- HTTPoison.get(file.url),
         {:ok, {config, guess_entries}} <- parse_csv(resp.body),
         {:ok, _} <-
           Message.create(
             from_channel,
             "Blind test init started, using `#{file.filename}` in channel #{Discord.channel(channel_id)}"
           ) do
      # use provided args and fallback to filename as default
      playlist_name = if args == [], do: file.filename, else: Enum.join(args, " ")

      party_players =
        Party.list_players()
        |> MapSet.new()

      {:ok, _} =
        Game.start(
          {author.id, O2M.Config.get(:guild), channel_id, file.url, playlist_name, config,
           party_players},
          {guess_entries, O2M.Config.get(:bt_cache), channel_id, from_channel,
           config.guess_duration}
        )

      {:ok, "__Download worker started__ : #{length(guess_entries)} song(s) to download"}
    else
      error -> error
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

  def parse_custom_kv(kv) do
    case String.split(kv, ":=")
         |> Enum.map(&String.trim/1)
         |> Enum.map(fn e -> String.trim(e, "\"") end) do
      [k, v] ->
        atom = String.to_atom(k)

        if Map.has_key?(%Config{}, atom) do
          cond do
            atom in [:f1, :f2] ->
              if String.valid?(v) && String.length(v) <= @max_field_len do
                {:ok, {atom, v}}
              else
                {:error,
                 "value #{v} for key #{k} is invalid (not a valid string or max length reached)"}
              end

            atom in [:guess_duration, :transition_duration] ->
              case Integer.parse(v, 10) do
                :error ->
                  {:error, "value #{v} for key #{k} is invalid (not an integer)"}

                {parsed, _} ->
                  if parsed >= @min_duration,
                    do: {:ok, {atom, parsed}},
                    else: {:error, {"value #{v} is not an integer value >= #{@min_duration}"}}
              end

            atom in [:error_threshold] ->
              case Integer.parse(v, 10) do
                :error ->
                  {:error, "value #{v} for key #{k} is invalid (not an integer)"}

                {parsed, _} ->
                  if parsed >= 0 && parsed <= 100,
                    do: {:ok, {atom, parsed / 100}},
                    else: {:error, {"value #{v} is not between 0 and 100"}}
              end

            atom in [:f1_scoring, :f2_scoring, :both_scoring] ->
              case Integer.parse(v, 10) do
                :error ->
                  {:error, "value #{} for key #{k} is invalid (not an integer)"}

                {parsed, _} ->
                  if parsed > 0,
                    do: {:ok, {atom, parsed}},
                    else: {:error, {"value #{v} is not a positive integer"}}
              end
          end
        else
          {:error, "#{atom} is not a valid config key in customize directive"}
        end

      _ ->
        {:error, "invalid key value pair #{kv} in customize directive"}
    end
  end

  @doc """
  Parse the csv file to create guess entries

  Returns all guess entries from this file in a MapSet
  """
  def parse_csv(content) do
    Logger.info("Parsing CSV", data: content)

    content
    |> String.replace("\r", "")
    |> String.replace(";", ",")
    |> String.split("\n")
    |> Enum.with_index()
    |> Enum.reduce_while(
      {:ok, {%Config{}, []}},
      fn {l, i}, {:ok, {conf, acc}} ->
        # skips comments and emtpy lines
        if !String.starts_with?(l, "#") and l != "" do
          case sanitize_playlist_line(l) do
            ["!customize" | config_kv] ->
              case parse_config_line(config_kv) do
                {:ok, config} ->
                  {:cont, {:ok, {config, acc}}}

                err ->
                  {:halt, err}
              end

            [url, f1s, f2s] ->
              uri = URI.parse(url)

              cond do
                !String.valid?(l) ->
                  {:halt,
                   {:error,
                    "Line #{i + 1} contains an invalid character, ensure it contains only UTF-8 characters"}}

                length(acc) > @playlist_size_limit ->
                  {:halt, {:error, "Playlist size limit reached #{@playlist_size_limit}"}}

                youtube?(uri) ->
                  entry = %GuessEntry{
                    url: url,
                    f1s: Enum.map(String.split(f1s, "|"), &BlindTest.sanitize_input/1),
                    f2s: Enum.map(String.split(f2s, "|"), &BlindTest.sanitize_input/1)
                  }

                  {:cont, {:ok, {conf, Enum.concat(acc, [entry])}}}

                true ->
                  {:halt,
                   {:error, "URL #{url} is not a valid youtube url (line #{i + 1}: `#{l}`)"}}
              end

            _ ->
              {:halt, {:error, "Can't parse line #{i + 1}: `#{l}`"}}
          end
        else
          {:cont, {:ok, {conf, acc}}}
        end
      end
    )
  end

  defp youtube?(uri) do
    String.contains?(uri.host, "youtu.be") || String.contains?(uri.host, "youtube")
  end

  defp sanitize_playlist_line(line) do
    String.replace(line, "\"", "") |> String.split(",")
  end

  defp parse_config_line(config_kv) do
    Enum.reduce_while(config_kv, {:ok, %Config{}}, fn kv, {:ok, config} ->
      case parse_custom_kv(kv) do
        {:ok, {k, v}} ->
          {:cont, {:ok, Map.put(config, k, v)}}

        err ->
          {:halt, err}
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
    input
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  @doc """
  Sanitizes inputs from both CSV and answer

  Returns sanitized input

  ## Examples
      iex> BlindTest.sanitize_input("ab'''''c")
      "abc"
  """
  def sanitize_input(input) do
    input
    |> String.normalize(:nfd)
    |> String.trim()
    |> String.replace(~r/[^a-zA-Z0-9 -]/, "")
    |> String.replace(~r/\s+/, " ")
    |> String.downcase()
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
        Message.react(bt_channel_id, msg.id, %Nostrum.Struct.Emoji{
          name: Emojos.get(:already)
        })

      :f1 ->
        # 🎤
        Message.react(bt_channel_id, msg.id, %Nostrum.Struct.Emoji{
          name: Emojos.get(:f1)
        })

        Message.create(
          bt_channel_id,
          "#{Discord.mention(msg.author.id)} just found the first field and earned #{points} points !"
        )

      :f2 ->
        # 💿
        Message.react(bt_channel_id, msg.id, %Nostrum.Struct.Emoji{
          name: Emojos.get(:f2)
        })

        Message.create(
          bt_channel_id,
          "#{Discord.mention(msg.author.id)} just found the second field and earned #{points} points !"
        )

      :both ->
        # 🏆
        Message.react(bt_channel_id, msg.id, %Nostrum.Struct.Emoji{
          name: Emojos.get(:both)
        })

        Message.create(
          bt_channel_id,
         "#{Discord.mention(msg.author.id)} just found both fields and earned #{points} points !"
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

  def exists?() do
    case process() do
      :none -> false
      _ -> true
    end
  end

  @doc """
  Ensure there is no running game

  Returns an :ok tuple
  """
  def ensure_not_running() do
    case Process.whereis(Game) do
      nil -> {:ok}
      _pid -> {:error, "There is already a blind test running in this guild"}
    end
  end

  @doc """
  Ensure there is a running game

  Return an :ok tuple
  """
  def ensure_running() do
    case Process.whereis(Game) do
      nil -> {:error, "There is no blind test running in this guild"}
      _pid -> {:ok}
    end
  end

  def status() do
    if Process.whereis(Game) != nil do
      cond do
        Process.whereis(Downloader.Worker) != nil ->
          :game_downloading

        BlindTest.finished?() ->
          :game_finished

        BlindTest.started?() ->
          :game_started

        true ->
          :game_not_started
      end
    else
      :none
    end
  end

  def ensure_channel(channel_id) do
    if O2M.Config.get(:bt_chan) == channel_id,
      do: {:ok},
      else:
        {:error,
         "To use this command, you have to interact with blind test in channel #{Discord.channel(O2M.Config.get(:bt_chan))}"}
  end

  def handle_message(msg, channel_id) do
    msg
    |> do_validate?(channel_id)
    |> do_validate(msg, channel_id)
  end

  def do_validate?(msg, channel_id) do
    BlindTest.exists?() &&
      channel_id == msg.channel_id &&
      BlindTest.guessing?() &&
      BlindTest.plays?(msg.author.id)
  end

  def do_validate(false, _, _), do: :ignore

  def do_validate(true, msg, channel_id) do
    case Game.validate(msg.content, msg.author.id) do
      {:ok, status, points} -> BlindTest.react_to_validation(msg, channel_id, status, points)
      :not_guessing -> :ignore
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
  def destroy(guild_id) do
    Nostrum.Voice.leave_channel(guild_id)

    # leave the channel
    case process() do
      {:one, pid} -> Process.exit(pid, :kill)
      _ -> nil
    end
  end
end

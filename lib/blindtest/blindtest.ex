defmodule BlindTest do
  require Logger

  # playlist max size, makes HolyRilettes happy
  @playlist_size_limit 42

  # max len of custom fields
  @max_field_len 100

  # min duration for both song and transition
  @min_duration 2

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
              guess_duration: 45,
              transition_duration: 15,
              error_treshold: 0.2
  end

  def check([], _, _), do: "Error no attachements found in this message"

  def check(attachements) do
    with {:ok, file} <- find_songs_attachement(attachements),
         {:ok, resp} <- Tesla.get(file.url),
         {:ok, {_, guess_entries}} <- parse_csv(resp.body) do
      {:ok, {file.filename, guess_entries}}
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
         {:ok, {config, guess_entries}} <- parse_csv(resp.body),
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
          {author.id, guild, channel_id, file.url, playlist_name, config},
          {guess_entries, cache, channel_id, from_channel, config.guess_duration}
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

            atom in [:error_treshold] ->
              case Integer.parse(v, 10) do
                :error ->
                  {:error, "value #{v} for key #{k} is invalid (not an integer)"}

                {parsed, _} ->
                  if parsed >= 0 && parsed <= 100,
                    do: {:ok, {atom, parsed / 100}},
                    else: {:error, {"value #{v} is not between 0 and 100"}}
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

    String.replace(content, "\r", "")
    |> String.replace(";", ",")
    |> String.split("\n")
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, {%Config{}, []}}, fn {l, i}, {:ok, {conf, acc}} ->
      # skips comments and emtpy lines
      if !String.starts_with?(l, "#") and l != "" do
        case String.replace(l, "\"", "") |> String.split(",") do
          ["!customize" | args] ->
            case Enum.reduce_while(args, {:ok, %Config{}}, fn kv, {:ok, config} ->
                   case parse_custom_kv(kv) do
                     {:ok, {k, v}} ->
                       {:cont, {:ok, Map.put(config, k, v)}}

                     err ->
                       {:halt, err}
                   end
                 end) do
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

              String.contains?(uri.host, "youtu.be") || String.contains?(uri.host, "youtube") ->
                {:cont,
                 {:ok,
                  {conf,
                   acc ++
                     [
                       %GuessEntry{
                         url: url,
                         f1s: Enum.map(String.split(f1s, "|"), &BlindTest.sanitize_input/1),
                         f2s: Enum.map(String.split(f2s, "|"), &BlindTest.sanitize_input/1)
                       }
                     ]}}}

              true ->
                {:halt, {:error, "URL #{url} is not a valid youtube url (line #{i + 1}: `#{l}`)"}}
            end

          _ ->
            {:halt, {:error, "Can't parse line #{i + 1}: `#{l}`"}}
        end
      else
        {:cont, {:ok, {conf, acc}}}
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
    String.normalize(input, :nfd)
    |> String.replace(~r/[^a-zA-Z0-9 -]/, "")
    |> String.replace(~r/\s+/, " ")
    |> String.downcase()
  end

  @doc """
  Verify if current answer is the first field, the second field or both

  Returns an atom describing the answer status

  ## Examples
      iex> BlindTest.verify_answer(%BlindTest.GuessEntry{f1s: ["Spiritbox"], f2s: ["Holly Roller"]}, "spiritbox holl roller")
      :both
  """
  def verify_answer(expected, proposal, threshold \\ 0.2) do
    sanitized = sanitize_input(proposal)

    valid? =
      &(Levenshtein.distance(&1, sanitized) /
          String.length(Enum.max([&1, sanitized])) < threshold)

    both_combinations =
      for f1 <- expected.f1s, f2 <- expected.f2s do
        ["#{f1} #{f2}", "#{f2} #{f1}"]
      end

    cond do
      Enum.find_value(List.flatten(both_combinations), false, &valid?.(&1)) ->
        :both

      Enum.find_value(expected.f1s, false, &valid?.(&1)) ->
        :f1

      Enum.find_value(expected.f2s, false, &valid?.(&1)) ->
        :f2

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

      :f1 ->
        # 🎤
        Nostrum.Api.create_reaction(bt_channel_id, msg.id, %Nostrum.Struct.Emoji{
          name: Emojos.get(:f1)
        })

        Nostrum.Api.create_message(
          bt_channel_id,
          "#{Discord.mention(msg.author.id)} just found the first field and earned #{points} points !"
        )

      :f2 ->
        # 💿
        Nostrum.Api.create_reaction(bt_channel_id, msg.id, %Nostrum.Struct.Emoji{
          name: Emojos.get(:f2)
        })

        Nostrum.Api.create_message(
          bt_channel_id,
          "#{Discord.mention(msg.author.id)} just found the second field and earned #{points} points !"
        )

      :both ->
        # 🏆
        Nostrum.Api.create_reaction(bt_channel_id, msg.id, %Nostrum.Struct.Emoji{
          name: Emojos.get(:both)
        })

        Nostrum.Api.create_message(
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

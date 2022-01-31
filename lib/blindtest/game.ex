defmodule Game do
  @moduledoc """
  State Machine used for blind tests
  """

  use GenStateMachine, callback_mode: [:handle_event_function, :state_enter]

  defmodule CurrentGuess do
    @moduledoc """
    Current guess entry and status
    """
    defstruct [
      :entry,
      :pass,
      :started_at,
      f1_found: false,
      f2_found: false,
      failed: false
    ]
  end

  defmodule Data do
    @moduledoc """
    Data used in the state machine
    """
    defstruct [
      # downloader data
      :downloader,
      # author
      :author_id,
      # playlist url
      :playlist_url,
      # guild id
      :guild_id,
      # main channel id for this session
      :channel_id,
      # scores by player
      scores: %{},
      # current guess
      current_guess: %CurrentGuess{},
      # list of to guess entries
      to_guess: [],
      # total number of guess
      total: 0,
      # list of guessed entries
      guessed: [],
      # list of all players
      players: MapSet.new(),
      # playlist name from csv filename
      name: "",
      ready: false,
      # config
      config: %BlindTest.Config{},
      error_threshold: 0.2
    ]
  end

  @to_scoring %{:f1 => :f1_scoring, :f2 => :f2_scoring, :both => :both_scoring}

  @medals %{1 => "🥇", 2 => "🥈", 3 => "🥉"}

  def get_medals(), do: @medals

  def start(
        {author_id, guild_id, channel_id, playlist_url, playlist_name, config, party_players},
        dl_data
      ) do
    GenStateMachine.start(
      __MODULE__,
      {:waiting,
       %Game.Data{
         players: party_players,
         downloader: dl_data,
         author_id: author_id,
         playlist_url: playlist_url,
         guild_id: guild_id,
         channel_id: channel_id,
         name: playlist_name,
         config: config
       }},
      name: __MODULE__
    )
  end

  def init({state, data}) do
    Game.Monitor.monitor()
    {:ok, state, data}
  end

  # Handlers modifying state and data
  def handle_event({:call, from}, {:add_guess_entry, guess_entry}, :waiting, data) do
    {:keep_state, %{data | to_guess: [guess_entry | data.to_guess]},
     [{:reply, from, {:ok, :added}}]}
  end

  def handle_event({:call, _from}, {:add_guess_entry, _guess_entry}, _state, _data) do
    :keep_state_and_data
  end

  def handle_event({:call, from}, :start_game, :ready, data) do
    cond do
      MapSet.size(data.players) == 0 ->
        {:keep_state_and_data, [{:reply, from, {:error, :no_players}}]}

      !Nostrum.Voice.ready?(data.guild_id) ->
        {:keep_state_and_data, [{:reply, from, {:error, :vocal_not_ready}}]}

      length(data.to_guess) == 0 ->
        {:keep_state_and_data, [{:reply, from, {:error, :no_guess}}]}

      true ->
        {:next_state, :guessing,
         %{
           data
           | :to_guess => Enum.reverse(data.to_guess),
             :total => length(data.to_guess)
         }, [{:reply, from, {:ok, data.channel_id}}]}
    end
  end

  def handle_event({:call, from}, :start_game, state, _data)
      when state in [:guessing, :transition, :finished] do
    {:keep_state_and_data, [{:reply, from, {:error, :running}}]}
  end

  def handle_event({:call, from}, :start_game, _state, _data) do
    {:keep_state_and_data, [{:reply, from, {:error, :not_ready}}]}
  end

  def handle_event({:call, from}, :set_ready, :waiting, data) do
    Nostrum.Api.create_message(
      data.channel_id,
      embed: %Nostrum.Struct.Embed{
        :title => "Blind test \"#{data.name}\" is ready !",
        :description => "Watch out ! Join vocal channel !",
        :fields => [
          %Nostrum.Struct.Embed.Field{
            name: "Start command",
            value: "`#{Application.fetch_env!(:o2m, :prefix)}bt start`"
          }
        ],
        :color => Colors.get_color(:info)
      }
    )

    {:next_state, :ready, data, [{:reply, from, {:ok, data.channel_id}}]}
  end

  def handle_event({:call, from}, {:validate, answer, user_id}, :guessing, data) do
    current_guess = data.current_guess

    status =
      case verify_answer(current_guess.entry, answer, data.config.error_treshold) do
        :f2 ->
          (!current_guess.f2_found && :f2) || :already

        :f1 ->
          (!current_guess.f1_found && :f1) || :already

        :both ->
          if !current_guess.f1_found && !current_guess.f2_found do
            :both
          else
            (!current_guess.f1_found && :f1) || :f2
          end

        value ->
          value
      end

    # if not found in map, return 0
    earned = Map.get(data.config, Map.get(@to_scoring, status, status), 0)

    # update scores
    new_scores = Map.update(data.scores, user_id, earned, &(&1 + earned))

    # update current guess
    updated_cg = %{
      current_guess
      | :f2_found => current_guess.f2_found || status == :both || status == :f2,
        :f1_found => current_guess.f1_found || status == :both || status == :f1
    }

    # update all data
    updated_data = %{
      data
      | :scores => new_scores,
        :current_guess => updated_cg
    }

    resp = {:ok, status, earned}

    if updated_data.current_guess.f1_found &&
         updated_data.current_guess.f2_found do
      {:next_state, :guess_results, updated_data, [{:reply, from, resp}]}
    else
      {:next_state, :guessing, updated_data, [{:reply, from, resp}]}
    end
  end

  def handle_event({:call, from}, {:validate, _answer, _user_id}, _, _data),
    do: {:keep_state_and_data, [{:reply, from, :not_guessing}]}

  def handle_event({:call, from}, {:pass, user_id}, :guessing, data) do
    if !MapSet.member?(data.current_guess.pass, user_id) do
      updated_cg = %{data.current_guess | :pass => MapSet.put(data.current_guess.pass, user_id)}

      if MapSet.size(data.players) == MapSet.size(updated_cg.pass) do
        {:next_state, :guess_results, %{data | :current_guess => updated_cg},
         [{:reply, from, {:ok, :skips}}]}
      else
        {:keep_state, %{data | :current_guess => updated_cg}, [{:reply, from, {:ok, :passed}}]}
      end
    else
      {:keep_state_and_data, [{:reply, from, {:error, :already_passed}}]}
    end
  end

  def handle_event({:call, from}, {:pass, _user_id}, _state, _data) do
    {:keep_state_and_data, [{:reply, from, {:error, :not_guessing}}]}
  end

  def handle_event({:call, from}, {:leave, user_id}, _, data) do
    if MapSet.member?(data.players, user_id) do
      {:keep_state, %{data | :players => MapSet.delete(data.players, user_id)},
       [{:reply, from, {:ok, :removed}}]}
    else
      {:keep_state_and_data, [{:reply, from, {:error, :not_playing}}]}
    end
  end

  def handle_event({:call, from}, {:join, user_id}, _, data) do
    players = MapSet.put(data.players, user_id)

    if MapSet.size(data.players) != MapSet.size(players) do
      {:keep_state,
       %{
         data
         | :players => players,
           :scores => Map.put(data.scores, user_id, 0)
       }, [{:reply, from, {:ok, :added}}]}
    else
      {:keep_state_and_data, [{:reply, from, {:ok, :duplicate}}]}
    end
  end

  # Handlers when timeouts triggers
  def handle_event(:timeout, :transition_notification, :transition, data) do
    Nostrum.Api.create_message(data.channel_id, "Listen ! Next song is coming !")
    :keep_state_and_data
  end

  def handle_event(:state_timeout, :transition_end, :transition, data) do
    {:next_state, :guessing, data}
  end

  def handle_event(:state_timeout, :not_guessed, :guessing, data) do
    {:next_state, :guess_results, data}
  end

  def handle_event(:state_timeout, :guess_playing_error, :guessing, data) do
    Nostrum.Api.create_message(
      data.channel_id,
      "An error occured while trying to play this guess, moving on to the next one"
    )

    {:next_state, :guess_results, data}
  end

  def handle_event(:state_timeout, :ended, :result, data) do
    {:next_state, :guessing, data,
     [{:state_timeout, data.config.guess_duration * 1000, :not_guessed}]}
  end

  def handle_event(:state_timeout, :guess_results_timeout, :guess_results, data) do
    case data.to_guess do
      [] -> {:next_state, :finished, data}
      _ -> {:next_state, :transition, data}
    end
  end

  # Handlers when entering a state
  def handle_event(:enter, _event, :guessing, data) do
    [current | rest] = data.to_guess

    updated_data = %{
      data
      | :to_guess => rest,
        :current_guess => %CurrentGuess{
          :pass => MapSet.new(),
          :started_at => DateTime.utc_now(),
          :entry => current,
          :f1_found => false,
          :f2_found => false
        }
    }

    case Cache.path(current.url) do
      {:ok, p} ->
        Nostrum.Api.create_message(data.channel_id,
          embed: %Nostrum.Struct.Embed{
            :title => "▶️ Playing song (#{data.config.guess_duration}s)",
            :description => "Guess #{length(data.guessed) + 1} of #{data.total}",
            :color => Colors.get_color(:warning)
          }
        )

        Nostrum.Voice.play(O2M.Application.from_env_to_int(:o2m, :guild), p, :url)

        {:keep_state, updated_data,
         [{:state_timeout, data.config.guess_duration * 1000, :not_guessed}]}

      {:error, reason} ->
        Nostrum.Api.create_message(data.channel_id, reason)

        {:keep_state, updated_data, [{:state_timeout, 0, :guess_playing_error}]}
    end
  end

  def handle_event(:enter, _event, :waiting, data) do
    guild = O2M.Application.from_env_to_int(:o2m, :guild)
    voice = O2M.Application.from_env_to_int(:o2m, :bt_vocal)
    Nostrum.Voice.join_channel(guild, voice)

    # Start the downloader worker inside the game statem
    Downloader.Worker.start_link(data.downloader)

    Nostrum.Api.create_message(
      data.channel_id,
      embed: %Nostrum.Struct.Embed{
        :title => "🎧 Here we go for a new blind test !",
        :description => "Boup bip boup !",
        :fields => [
          %Nostrum.Struct.Embed.Field{
            name: "Name",
            value: data.name
          },
          %Nostrum.Struct.Embed.Field{
            name: "Auto-join",
            value: "#{MapSet.size(data.players)} player(s)"
          },
          %Nostrum.Struct.Embed.Field{
            name: "Join command",
            value: "`#{Application.fetch_env!(:o2m, :prefix)}bt join`"
          },
          %Nostrum.Struct.Embed.Field{
            name: "Rules",
            value:
              "**First field** : #{data.config.f1}, **second field** : #{data.config.f2}, **durations** : ▶️ #{data.config.guess_duration}s | ⏸️ #{data.config.transition_duration}s"
          },
          %Nostrum.Struct.Embed.Field{
            name: "Scoring",
            value:
              "#{data.config.f1_scoring} (#{data.config.f1}) | #{data.config.f2_scoring} (#{data.config.f2}) | #{data.config.both_scoring} (both)"
          }
        ],
        :color => Colors.get_color(:success)
      }
    )

    Nostrum.Api.create_message(
      data.channel_id,
      "_Prepared with love by #{Discord.mention(data.author_id)}_"
    )

    :keep_state_and_data
  end

  def handle_event(:enter, _event, :guess_results, data) do
    current_guess = data.current_guess

    default_fields = [
      %Nostrum.Struct.Embed.Field{
        name: "Accepted answers for _#{data.config.f1}_",
        value:
          current_guess.entry.f1s
          |> Enum.map(&BlindTest.titleize/1)
          |> Enum.join(", ")
      },
      %Nostrum.Struct.Embed.Field{
        name: "Accepted answers for _#{data.config.f2}_",
        value:
          current_guess.entry.f2s
          |> Enum.map(&BlindTest.titleize/1)
          |> Enum.join(", ")
      }
    ]

    {message, color, fields} =
      cond do
        current_guess.f1_found && current_guess.f2_found ->
          dur = Timex.diff(DateTime.utc_now(), current_guess.started_at, :seconds)

          {"Bravo ! You found both **#{data.config.f1}** and **#{data.config.f2}** fields",
           Colors.get_color(:success),
           [
             %Nostrum.Struct.Embed.Field{
               name: "Time",
               value: "#{dur}s"
             }
           ] ++ default_fields}

        current_guess.f1_found ->
          {"Just found #{data.config.f1} field...", Colors.get_color(:info), default_fields}

        current_guess.f2_found ->
          {"Nice but #{data.config.f1} is missing...", Colors.get_color(:info), default_fields}

        current_guess.failed ->
          {"Oops, sorry, there was an error with this one", Colors.get_color(:danger),
           default_fields}

        true ->
          {"No #{data.config.f1}, no #{data.config.f2}, duh !", Colors.get_color(:danger),
           default_fields}
      end

    Nostrum.Api.create_message(
      data.channel_id,
      embed: %Nostrum.Struct.Embed{
        title:
          "🎼 It was #{BlindTest.titleize(Enum.max(current_guess.entry.f1s))} - #{BlindTest.titleize(Enum.max(current_guess.entry.f2s))}",
        description: message,
        color: color,
        url: current_guess.entry.url,
        fields: fields
      }
    )

    {:keep_state, %{data | guessed: [current_guess | data.guessed]},
     [{:state_timeout, 0, :guess_results_timeout}]}
  end

  def handle_event(:enter, _event, :transition, data) do
    Nostrum.Voice.stop(O2M.Application.from_env_to_int(:o2m, :guild))

    Nostrum.Api.create_message(data.channel_id,
      embed: %Nostrum.Struct.Embed{
        :title => "🎶 Transition ! (#{data.config.transition_duration}s)",
        :description => "🤬 It's taunt time ! ✨",
        :color => Colors.get_color(:warning)
      }
    )

    {:keep_state_and_data,
     [
       {:state_timeout, data.config.transition_duration * 1000, :transition_end},
       {:timeout, div(data.config.transition_duration, 2) * 1000, :transition_notification}
     ]}
  end

  def handle_event(:enter, _event, :finished, data) do
    Nostrum.Voice.stop(O2M.Application.from_env_to_int(:o2m, :guild))

    Nostrum.Api.create_message(data.channel_id,
      embed: %Nostrum.Struct.Embed{
        :title => "Thank you for participating ! ❤️",
        :description =>
          "Bip boup bip boup 💾 computing results 💽, adding results to leaderboard 📈, do not forget to destroy me !",
        :color => Colors.get_color(:info),
        fields: [
          %Nostrum.Struct.Embed.Field{
            name: "Playlist File",
            value: data.playlist_url
          }
        ]
      }
    )

    Leaderboard.update(data.scores)

    Party.add_game(%Party.GameResult{name: data.name, scores: data.scores})

    Nostrum.Api.create_message(data.channel_id, generate_ranking(data.scores))

    :keep_state_and_data
  end

  # Default event handler when entering a state, do nothing
  def handle_event(:enter, _, _, _), do: :keep_state_and_data

  # Handlers fetching states and data
  def handle_event({:call, from}, {:plays?, id}, _state, data),
    do: {:keep_state_and_data, [{:reply, from, {:ok, MapSet.member?(data.players, id)}}]}

  def handle_event({:call, from}, :guessing?, state, _data),
    do: {:keep_state_and_data, [{:reply, from, {:ok, state == :guessing}}]}

  def handle_event({:call, from}, :finished?, state, _data),
    do: {:keep_state_and_data, [{:reply, from, {:ok, state == :finished}}]}

  def handle_event({:call, from}, :started?, state, _data),
    do:
      {:keep_state_and_data, [{:reply, from, {:ok, state == :guessing || state == :transition}}]}

  def handle_event({:call, from}, :get_channel_id, _state, data),
    do: {:keep_state_and_data, [{:reply, from, {:ok, data.channel_id}}]}

  def handle_event({:call, from}, :get_players, _state, data),
    do: {:keep_state_and_data, [{:reply, from, {:ok, data.players}}]}

  def handle_event({:call, from}, {:contains_player, id}, _state, data) do
    if MapSet.member?(data.players, id) do
      {:keep_state_and_data, [{:reply, from, {:ok}}]}
    else
      {:keep_state_and_data,
       [{:reply, from, {:error, "User #{Discord.mention(id)} is not playing in this game"}}]}
    end
  end

  def handle_event({:call, from}, :get_ranking, state, _data)
      when state == :waiting or state == :ready do
    {:keep_state_and_data, [{:reply, from, {:error, :no_ranking}}]}
  end

  def handle_event({:call, from}, :get_ranking, _state, data) do
    {:keep_state_and_data, [{:reply, from, {:ok, generate_ranking(data.scores)}}]}
  end

  def handle_event({:call, from}, :get_author, _state, data) do
    {:keep_state_and_data, [{:reply, from, {:ok, data.author_id}}]}
  end

  def generate_ranking(scores) do
    scores
    |> Enum.to_list()
    |> Enum.sort(fn {_k1, v1}, {_k2, v2} -> v1 > v2 end)
    |> Enum.with_index()
    |> Enum.reduce(
      "",
      fn {{user, score}, index}, acc ->
        "#{acc}\n#{index + 1} | #{Discord.mention(user)} - **#{score}** point(s)#{if index + 1 <= 3,
          do: " - #{Map.get(@medals, index + 1)}"}"
      end
    )
  end

  def start_game() do
    GenStateMachine.call(__MODULE__, :start_game)
  end

  def get_ranking() do
    GenStateMachine.call(__MODULE__, :get_ranking)
  end

  def get_players() do
    GenStateMachine.call(__MODULE__, :get_players)
  end

  def contains_player(id) do
    GenStateMachine.call(__MODULE__, {:contains_player, id})
  end

  def get_author() do
    GenStateMachine.call(__MODULE__, :get_author)
  end

  def add_player(player_id) do
    GenStateMachine.call(__MODULE__, {:join, player_id})
  end

  def remove_player(player_id) do
    GenStateMachine.call(__MODULE__, {:leave, player_id})
  end

  def channel_id() do
    GenStateMachine.call(__MODULE__, :get_channel_id)
  end

  def add_guess(entry) do
    GenStateMachine.call(__MODULE__, {:add_guess_entry, entry})
  end

  def player_pass(player_id) do
    GenStateMachine.call(__MODULE__, {:pass, player_id})
  end

  def set_ready() do
    GenStateMachine.call(Game, :set_ready)
  end

  def validate(content, author_id) do
    GenStateMachine.call(Game, {:validate, content, author_id})
  end

  @doc """
  Verify if current answer is the first field, the second field or both

  Returns an atom describing the answer status

  ## Examples
      iex> Game.verify_answer(%BlindTest.GuessEntry{f1s: ["Spiritbox"], f2s: ["Holly Roller"]}, "spiritbox holl roller")
      :both
  """
  def verify_answer(expected, proposal, threshold \\ 0.2) do
    sanitized = BlindTest.sanitize_input(proposal)

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
end

defmodule Game.Monitor do
  @moduledoc """
  A simple GenServer used to monitor a game process
  """

  use GenServer
  require Logger

  def init(channel_id) do
    # On init try to attach to an existing game process
    # In case of Monitor failure, this will reattach the monitor to the game process
    if Process.whereis(Game) do
      Process.monitor(Game)
    end

    {:ok, channel_id}
  end

  def start_link(channel_id) do
    GenServer.start_link(__MODULE__, channel_id, name: __MODULE__)
  end

  def monitor() do
    GenServer.cast(__MODULE__, :monitor)
  end

  def handle_cast(:monitor, channel_id) do
    Process.monitor(Game)
    {:noreply, channel_id}
  end

  def handle_info({:DOWN, _ref, :process, object, reason}, channel_id) when reason != :killed do
    Logger.info("Game process monitor received a game crash message", reason: reason, data: object)

    Nostrum.Api.create_message!(
      channel_id,
      embed: %Nostrum.Struct.Embed{
        :title => "KABOOM ALERT, I just exploded, sorry.",
        :description => "💥",
        :color => Colors.get_color(:danger)
      }
    )

    {:noreply, channel_id}
  end

  def handle_info({:DOWN, _ref, :process, _object, _reason}, channel_id),
    do: {:noreply, channel_id}
end

defmodule O2M.Commands.Bt do
  @moduledoc """
  Bt module handles call to bind test command
  """
  import Discord
  require Logger
  alias Downloader.Yydl
  alias O2M.Config

  @subcmds [
    "init",
    "join",
    "leave",
    "players",
    "start",
    "ranking",
    "status",
    "pass",
    "destroy",
    "help",
    "rules",
    "lboard",
    "bam",
    "check",
    "party",
    "events"
  ]

  @subhandlers %{
    "init" => &__MODULE__.init/2,
    "join" => &__MODULE__.join/2,
    "leave" => &__MODULE__.leave/2,
    "players" => &__MODULE__.players/2,
    "start" => &__MODULE__.start/2,
    "ranking" => &__MODULE__.ranking/2,
    "status" => &__MODULE__.status/2,
    "pass" => &__MODULE__.pass/2,
    "destroy" => &__MODULE__.destroy/2,
    "help" => &__MODULE__.help/2,
    "rules" => &__MODULE__.rules/2,
    "lboard" => &__MODULE__.lboard/2,
    "bam" => &__MODULE__.bam/2,
    "check" => &__MODULE__.check/2,
    "party" => &__MODULE__.party/2,
    "events" => &__MODULE__.events/2
  }

  @doc """
  Handle blind test init command
  """
  def init(args, msg) do
    with {:ok, _chan} <- is_chan_private(msg.channel_id),
         {:ok} <- member_has_persmission(msg.author, Config.get(:bt_admin), Config.get(:guild)),
         {:ok} <- BlindTest.ensure_not_running() do
      BlindTest.init(msg.attachments, msg.author, msg.channel_id, args)
    else
      error -> error
    end
  end

  @doc """
  Handle blind test init command
  """
  def check(_args, msg) do
    with {:ok, _chan} <- is_chan_private(msg.channel_id),
         {:ok, {filename, guess_entries}} <- BlindTest.check(msg.attachments) do
      Nostrum.Api.create_message!(
        msg.channel_id,
        "✅ Syntax for playlist `#{filename}` checked : 👌"
      )

      Nostrum.Api.create_message!(
        msg.channel_id,
        "__Moving on to download checks__"
      )

      {:ok, start, to} = Downloader.parse_timestamps(0, 1)

      errors =
        Enum.reduce(guess_entries, 0, fn guess, acc ->
          with {:ok, data_url} <- Downloader.Yydl.get_url(guess.url),
               {:ok} <-
                 Yydl.get_data(%Yydl.DownloadData{
                   data_url: data_url,
                   url: guess.url,
                   ts_from: start,
                   ts_to: to,
                   output: "/dev/null",
                   check: true
                 }) do
            acc
          else
            {:error, _} ->
              Nostrum.Api.create_message(
                msg.channel_id,
                "__Downloader checker update__: error getting #{guess.url}"
              )

              acc + 1
          end
        end)

      reply =
        if errors == 0,
          do: "✅ No download errors in playlist `#{filename}` 👌",
          else:
            "❌ **#{errors} download error(s)** for #{length(guess_entries)} entries in playlist `#{filename}`"

      {:ok, reply}
    else
      error -> error
    end
  end

  @doc """
  Handle join commmand
  """
  def join(_args, msg) do
    with {:ok} <- BlindTest.ensure_running(),
         {:ok} <- BlindTest.ensure_channel(msg.channel_id) do
      Game.add_player(msg.author.id)

      # 👌
      Nostrum.Api.create_reaction(msg.channel_id, msg.id, %Nostrum.Struct.Emoji{
        name: Emojos.get(:joined)
      })

      {:ok, :silent}
    else
      error -> error
    end
  end

  @doc """
  Handle leave commmand
  """
  def leave(_args, msg) do
    with {:ok} <- BlindTest.ensure_running(),
         {:ok} <- BlindTest.ensure_channel(msg.channel_id) do
      reply =
        case Game.remove_player(msg.author.id) do
          {:ok, :removed} ->
            "User #{msg.author} quit the game... BOOOOOO !"

          {:error, :not_playing} ->
            "User #{msg.author} please **join a blind** test before leaving one 😛"
        end

      {:ok, reply}
    else
      error -> error
    end
  end

  @doc """
  Handle players command
  """
  def players(_args, msg) do
    with {:ok} <- BlindTest.ensure_running(),
         {:ok} <- BlindTest.ensure_channel(msg.channel_id) do
      {:ok, players_id} = Game.get_players()

      if MapSet.size(players_id) != 0 do
        {:ok, author_id} = Game.get_author()
        me = Nostrum.Cache.Me.get()

        players_in_vocal =
          Config.get(:guild)
          |> Nostrum.Cache.GuildCache.get!()
          |> Map.get(:voice_states)
          |> Enum.filter(fn v -> v.channel_id == Config.get(:bt_vocal) end)
          |> Enum.filter(fn v -> v.user_id != me.id && v.user_id != author_id end)
          |> Enum.map(fn v -> v.user_id end)
          |> MapSet.new()

        list =
          Enum.reduce(
            MapSet.to_list(players_id),
            "**Player(s) in this session (#{MapSet.size(players_id)}) :**\n",
            fn elem, acc ->
              "#{acc}\n\t #{mention(elem)}"
            end
          )

        players_id = MapSet.delete(players_id, author_id)

        missing_in_game =
          if MapSet.subset?(players_in_vocal, players_id) do
            "**Every member in vocal channel is in game**"
          else
            players_in_vocal
            |> MapSet.difference(players_id)
            |> MapSet.to_list()
            |> Enum.reduce(
              "**Missing player(s) from vocal channel :**\n",
              fn elem, acc -> "#{acc}\n\t #{mention(elem)}" end
            )
          end

        missing_in_vocal =
          if MapSet.subset?(players_id, players_in_vocal) do
            "**Every player is connected to the vocal channel**"
          else
            MapSet.difference(players_id, players_in_vocal)
            |> MapSet.to_list()
            |> Enum.reduce(
              "**Missing player(s) in vocal channel :**\n",
              fn elem, acc -> "#{acc}\n\t #{mention(elem)}" end
            )
          end

        {:ok, Enum.join([list, missing_in_game, missing_in_vocal], "\n\n")}
      else
        {:ok, "There is no players yet in this session"}
      end
    else
      error -> error
    end
  end

  @doc """
  Handle start command
  """
  def start(_args, msg) do
    with {:ok} <- BlindTest.ensure_running(),
         {:ok} <- member_has_persmission(msg.author, Config.get(:bt_admin), Config.get(:guild)),
         {:ok} <- BlindTest.ensure_channel(msg.channel_id) do
      case Game.start_game() do
        {:ok, _} ->
          Nostrum.Api.create_message!(
            msg.channel_id,
            embed: %Nostrum.Struct.Embed{
              :title => "🏁 Blind test is starting !",
              :description => "Good luck and have fun !",
              :color => Colors.get_color(:success)
            }
          )

          {:ok, :silent}

        {:error, :no_guess} ->
          {:ok, "Sorry but there is no guess for this game"}

        {:error, :vocal_not_ready} ->
          {:ok, "Sorry but vocal channel is not ready"}

        {:error, :no_players} ->
          {:ok, "Sorry but I can't start a blind test without players... 🙃"}

        {:error, :not_ready} ->
          {:ok, "Sorry but blind test is not ready yet ⏳"}

        {:error, :running} ->
          {:ok, "Sorry but a blind test is already running 🎮"}

        error ->
          error
      end
    else
      error -> error
    end
  end

  @doc """
  Handle ranking command
  """
  def ranking(_args, msg) do
    with {:ok} <- BlindTest.ensure_running(),
         {:ok} <- BlindTest.ensure_channel(msg.channel_id) do
      case Game.get_ranking() do
        {:ok, message} ->
          {:ok, message}

        {:error, :no_ranking} ->
          {:ok, "Sorry but there is no ranking (yet) in this blind test"}
      end
    else
      error -> error
    end
  end

  @doc """
  Handle pass command
  """
  def pass(_args, msg) do
    with {:ok} <- BlindTest.ensure_running(),
         {:ok} <- BlindTest.ensure_channel(msg.channel_id),
         {:ok} <- Game.contains_player(msg.author.id) do
      case Game.player_pass(msg.author.id) do
        {:ok, :passed} ->
          # ⏩
          Nostrum.Api.create_reaction(msg.channel_id, msg.id, %Nostrum.Struct.Emoji{
            name: Emojos.get(:passed)
          })

          {:ok, :silent}

        {:ok, :skips} ->
          # ⏩
          Nostrum.Api.create_reaction(msg.channel_id, msg.id, %Nostrum.Struct.Emoji{
            name: Emojos.get(:passed)
          })

          {:ok, "STOP THE COUNT, I skip this guess"}

        {:ok, :already_passed} ->
          # 🖕
          Nostrum.Api.create_reaction(msg.channel_id, msg.id, %Nostrum.Struct.Emoji{
            name: Emojos.get(:already_passed)
          })

          {:ok, :silent}

        {:error, :not_guessing} ->
          {:ok, "You can only pass a track when **guessing one**"}
      end
    else
      error -> error
    end
  end

  @doc """
  Handle status command
  """
  def status(_, _) do
    case BlindTest.status() do
      :none ->
        {:ok, "No blind test running"}

      status ->
        {:ok, channel_id} = Game.channel_id()

        reply =
          case status do
            :game_downloading ->
              "Blind test initialization running in channel #{Discord.channel(channel_id)}"

            :game_finished ->
              "Blind test ended in channel #{Discord.channel(channel_id)}"

            :game_not_started ->
              "Blind test is about to start in channel #{Discord.channel(channel_id)}"

            :game_started ->
              "Blind test is running in channel #{Discord.channel(channel_id)}"
          end

        {:ok, reply}
    end
  end

  @doc """
  Handle destroy command
  """
  def destroy(_args, msg) do
    guild_id = Config.get(:guild)

    with {:ok} <- BlindTest.ensure_running(),
         {:ok} <- member_has_persmission(msg.author, Config.get(:bt_admin), guild_id),
         {:ok} <- BlindTest.ensure_channel(msg.channel_id) do
      downloarder_pid = Process.whereis(Downloader.Worker)
      # kill downloader is any
      if downloarder_pid, do: Process.exit(downloarder_pid, :kill)
      # clean cache
      Cache.clean()
      # kill running BT process
      BlindTest.destroy(guild_id)

      Nostrum.Api.create_message(
        msg.channel_id,
        embed: %Nostrum.Struct.Embed{
          :title => "Okay ! Time to clean up ! 🧹",
          :description => "It was a pleasure ! See you next time ! 💋",
          :color => Colors.get_color(:danger)
        }
      )

      {:ok, :silent}
    else
      error -> error
    end
  end

  @doc """
  Handle help message
  """
  def help(_, _) do
    reply = "Available **bt** subcommands are :

    __Administration commands__ (requires privileges)

    **init**: init a new blind test, message should be a private message to the bot with a `.csv` file attached to it (`csv format: youtube.com/link,artist,title`)
    **start**: starts the blind test if ready
    **destroy**: destroy the running blind test

    __Players commands__ (only in dedicated bind test text channel)

    **join**: join a blind test
    **leave**: leave current blind test
    **players**: list all players for this session
    **pass**: when guessing a song, ask for skipping current guess
    **ranking**: list current ranking for this session
    **status**: fetch blind test status

    __Events commands__ (requires privileges)

    **events list**: list blind test events
    **events create date@time name**: date format YYYY-MM-DD@hh:mm eg 2022-01-29@21:00
    **events start id**: get the ID from the `list` command

    __Party commands__

    **party join**: join this party
    **party leave**: leave this party
    **party players**: list players in this party
    **party overview**: get an overview of the current party
    **party list**: list all the games for this party
    **party get <ID>**: get data about a specific game
    **party reset**: reset party data [admin]

    __Leaderboard commands__

    **lboard top**: print top 15 leaderboard
    **lboard set @user +<value>**: add value to @user score [admin]
    **lboard set @user -<value>**: substract value to @user score [admin]
    **lboard set @user =<value>**: set @user score to value [admin]
    **lboard get**: get asking user score

    __Help commands__

    **rules**: print rules and various informations about blind test
    **help**: to get this help message
    **check**: to check if a blindtest playlist is valid

    __How to guide__ : https://github.com/papey/o2m/wiki"

    {:ok, reply}
  end

  def rules(_, _) do
    reply = "**Blind test rules**

      __Reaction emojis__

      When joining :
      \t #{Emojos.get(:joined)}: message author joined the game

      When guessing :
      \t answer validation :
      \t\t #{Emojos.get(:both)}: message author found both fields
      \t\t #{Emojos.get(:f1)}: message author found the first field
      \t\t #{Emojos.get(:f2)}: message author found the second field
      \t\t #{Emojos.get(:already)}: message author found an answer, but too late !
      \t\t if no reactions added user answer is wrong
      \t pass
      \t\t #{Emojos.get(:passed)}: message author passed the current guess
      \t\t #{Emojos.get(:already_passed)}: message author already passed the current guess

      __Games points__

      Only the first get the points !

      Default scoring is :

      \t - **both fields** in the same message : **8 points**
      \t - **first field** found : **2 points**
      \t - **second field** found : **3 points**

      "

    {:ok, reply}
  end

  def lboard([], _msg) do
    {:error, "Missing instruction for `lboard` subcommand"}
  end

  def lboard(["top" | _], msg) do
    with {:ok} <- member_has_persmission(msg.author, Config.get(:bt_admin), Config.get(:guild)) do
      reply =
        Leaderboard.top()
        |> Enum.with_index()
        |> Enum.reduce(
          "**Leaderboard (top 15)**",
          fn {{user, score}, index}, acc ->
            "#{acc}\n#{index + 1} | #{mention(user)} - **#{score}** point(s)#{if index + 1 <= 3,
              do: " - #{Map.get(Game.get_medals(), index + 1)}"}"
          end
        )

      {:ok, reply}
    else
      error -> error
    end
  end

  def lboard(["set", _user, <<instruction::binary-size(1)>> <> points | _], msg) do
    with {:ok} <- member_has_persmission(msg.author, Config.get(:bt_admin), Config.get(:guild)),
         {:ok} <- BlindTest.ensure_channel(msg.channel_id) do
      case Integer.parse(points) do
        {val, _} ->
          [user | _] = msg.mentions

          case instruction do
            "=" ->
              Leaderboard.set(user.id, val)
              {:ok, "#{Discord.mention(user.id)}'s score set to #{val}"}

            "+" ->
              {:ok, updated} = Leaderboard.delta(user.id, val, &Kernel.+/2)
              {:ok, "#{Discord.mention(user.id)}'s score updated to #{updated} (+#{val})"}

            "-" ->
              {:ok, updated} = Leaderboard.delta(user.id, val, &Kernel.-/2)
              {:ok, "#{Discord.mention(user.id)}'s score updated to #{updated} (-#{val})"}

            _ ->
              {:error, "Not a valid set instruction"}
          end

        :error ->
          {:error, "#{points} is not a valid integer value"}
      end
    else
      error -> error
    end
  end

  def lboard(["set" | _], _msg) do
    {:error, "Missing arguments for `set` instruction"}
  end

  def lboard(["get" | _], msg) do
    total = Leaderboard.get(msg.author.id)
    {:ok, "Total for user #{mention(msg.author.id)} : #{if total == 0, do: "👌", else: total}"}
  end

  def lboard(_, _) do
    {:error, "Unsupported `lboard` instruction"}
  end

  def party(["reset" | _], msg) do
    with {:ok} <-
           Discord.member_has_persmission(msg.author, Config.get(:bt_admin), Config.get(:guild)) do
      Party.reset()
      {:ok, "🙌  Party cleared  🙌"}
    else
      error -> error
    end
  end

  def party(["list" | _], _msg) do
    reply =
      case Party.list_games() do
        [] ->
          "No games yet in this party"

        results ->
          Enum.reduce(results, "**List of games for this party :**\n", fn {id, result}, acc ->
            "#{acc}\n\t- ID : #{id} | Name : #{result.name}"
          end)
      end

    {:ok, reply}
  end

  def party(["overview" | _], _msg) do
    reply =
      case Party.list_games() do
        [] ->
          "No games yet in this party"

        games ->
          {names, total} =
            Enum.reduce(games, {[], %{}}, fn {_id, game}, {names, total} ->
              next_total =
                Enum.reduce(game.scores, total, fn {id, score}, acc ->
                  Map.update(acc, id, score, &(&1 + score))
                end)

              {names ++ ["`#{game.name}`"], next_total}
            end)

          "**All games for this party :** #{Enum.join(names, " / ")}\n\n**Ranking for this party :\n**#{Game.generate_ranking(total)}"
      end

    {:ok, reply}
  end

  def party(["get"], _msg), do: {:error, "This command needs a game ID"}

  def party(["get", id | _], _msg) do
    case Integer.parse(id) do
      {val, _} ->
        reply =
          case Party.get_game(val) do
            [] ->
              "No game found for game ID #{id}"

            [{_id, game} | _] ->
              "Ranking for game **#{game.name}** :\n#{Game.generate_ranking(game.scores)}"
          end

        {:ok, reply}

      _ ->
        {:error, "Result ID must be a valid integer value (received #{id})"}
    end
  end

  def party(["join" | _], msg) do
    Party.add_player(msg.author.id)

    # 👌
    Nostrum.Api.create_reaction(msg.channel_id, msg.id, %Nostrum.Struct.Emoji{
      name: Emojos.get(:joined)
    })

    {:ok, :silent}
  end

  def party(["leave" | _], msg) do
    Party.remove_player(msg.author.id)

    {:ok, "XOXO #{Discord.mention(msg.author.id)} 😗"}
  end

  def party(["players" | _], _) do
    reply =
      case Party.list_players() do
        [] ->
          "No players yet in this party"

        players ->
          total = length(players)

          Enum.reduce(
            players,
            "**Player(s) in this party (#{total}) :**\n",
            fn elem, acc ->
              "#{acc}\n\t- #{mention(elem)}"
            end
          )
      end

    {:ok, reply}
  end

  def party(_, _) do
    {:error, "Missing valid instruction for `party` subcommand"}
  end

  def events(["create", _ | []], _msg) do
    {:error, "Missing event name for `create` subcommand"}
  end

  def events(["create", date | args], msg) do
    guild_id = Config.get(:guild)

    with {:ok} <-
           Discord.member_has_persmission(msg.author, Config.get(:bt_admin), guild_id),
         {:ok, date} <- Timex.parse(date, "{YYYY}-{0M}-{D}@{h24}:{m}"),
         with_tz <- Timex.to_datetime(date, Config.get(:bt_events_tz)) do
      options = %{
        channel_id: Config.get(:bt_vocal),
        scheduled_start_time: with_tz,
        privacy_level: 2,
        name: Enum.join(args, " "),
        description: "🎸🤘🎼🎵",
        entity_type: 2
      }

      Nostrum.Api.create_guild_scheduled_event(guild_id, options)

      {:ok, "Event created ! 📅"}
    else
      error -> error
    end
  end

  def events(["create" | _], _msg) do
    {:error, "Missing arguments for `create` subcommand"}
  end

  def events(["list" | _], _msg) do
    case Nostrum.Api.get_guild_scheduled_events(Config.get(:guild)) do
      {:ok, events} ->
        reply =
          case Enum.filter(events, fn event -> event.description == "🎸🤘🎼🎵" end) do
            [] ->
              "No blind test event found"

            events ->
              init = "_Scheduled Blind Tests (#{length(events)}):_\n\n"

              Enum.reduce(events, init, fn event, acc ->
                "#{acc}\t- **#{event.name}** | _#{Timex.format!(event.scheduled_start_time, "{YYYY}-{0M}-{D}")}_ | ID : #{event.id}\n"
              end)
          end

        {:ok, reply}

      error ->
        error
    end
  end

  def events(["start", id | _], msg) do
    guild_id = Config.get(:guild)

    with {:ok} <-
           Discord.member_has_persmission(msg.author, Config.get(:bt_admin), guild_id),
         {:ok} <- BlindTest.ensure_channel(msg.channel_id),
         {:ok, event} <- Nostrum.Api.get_guild_scheduled_event(guild_id, id),
         {:ok, players} <- Nostrum.Api.get_guild_scheduled_event_users(guild_id, event.id) do
      Enum.map(players, fn p -> p.user.id end) |> Party.add_players()
      {:ok, "Lets go ! Have fun 🎸🤘🎼🎵"}
    else
      error -> error
    end
  end

  def events(["start"], _msg) do
    {:error, "Missing arguments for `start` subcommand"}
  end

  def events(_, _) do
    {:error, "Missing valid instruction for `events` subcommand"}
  end

  def bam(_, _) do
    reply =
      [
        "https://youtu.be/iRbnY8EK4Ew",
        "https://youtu.be/qcSeibiFJdI",
        "https://youtu.be/p-Q3zg8pgDg",
        "https://youtu.be/TE024YOfQNw",
        "https://youtu.be/Fye2KREpeJQ",
        "https://youtu.be/dM8WjgRA6o8",
        "https://youtu.be/Tq8u0uDK61E",
        "https://youtu.be/nUprJZMPM0c"
      ]
      |> Enum.random()

    {:ok, reply}
  end

  @doc """
  Handle and route blind-test subcommands
  """
  def handle(sub, args, msg) do
    if O2M.Config.get(:bt),
      do: do_handle(sub, args, msg),
      else: {:error, "Blind test is **not configured** on this Discord Guild 😢"}
  end

  def do_handle(sub, args, msg) when sub in @subcmds do
    Logger.info("Blind test command received", sub: sub, message: msg.content)

    handler_fun = Map.get(@subhandlers, sub)

    handler_fun.(args, msg)
  end

  def do_handle(sub, _args, _msg) do
    {:error, "Subcommand **#{sub}** of command **bt** is not supported"}
  end
end

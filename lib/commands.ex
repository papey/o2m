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

  defmodule Tmpl do
    require Logger
    import Announcements

    @moduledoc """
    An module handle call to an command
    """

    @doc """
    Handle Tmpl commands and route to sub commands
    """
    def handle(sub, args) do
      case sub do
        "add" ->
          add(args)

        "list" ->
          list(args)

        "delete" ->
          delete(args)

        "help" ->
          help(args)

        _ ->
          "Sorry but subcommand **#{sub}** of command **tmpl** is not supported"
      end
    end

    @doc """
    Add is used to add a template into DETS storage
    """
    # if not args provided
    def add([]) do
      "Error, missing template for `add` subcommand"
    end

    # if args provided
    def add(args) do
      # get template from args
      [template | _] =
        args
        |> Enum.join(" ")
        |> String.split("//")
        |> Enum.map(fn e -> String.trim(e) end)

      # get all keys
      keys = get_keys(template)

      # check if only mandatory/allowed keys are set
      case Announcements.valid?(keys, template) do
        true ->
          # if ok, use template
          case Announcements.Storage.put(template) do
            true ->
              "Template `#{template}` added succesfully"

            false ->
              "Template `#{template}` already exists"

            {:warning, message} ->
              message

            {:error, reason} ->
              Logger.error("Error while saving template to DETS file", reason: reason)
              reason
          end

        false ->
          # if not, fallback to a default one
          "This template is invalid, please ensure all required keys are set (__mandatory keys : #{m2s()}__) and respect length limit (**#{Announcements.limit()} characters)**"
      end
    end

    @doc """
    List is used to list templates
    """
    def list(_) do
      case Announcements.Storage.get_all() do
        [] ->
          "There is no registered templates fallback to default one"

        templates ->
          Enum.reduce(templates, "", fn {k, v}, acc ->
            "#{acc}\n_id_ : **#{k}** - _template_ : `#{v}`"
          end)
      end
    end

    @doc """
    Delete is used to delete a specific template from DETS
    """
    # if no args provided
    def delete([]) do
      "Missing identificator for `delete` subcommand"
    end

    # If args provided
    def delete(args) do
      # get hash from args
      hash =
        args
        |> Enum.join(" ")
        |> String.split("//")
        |> Enum.map(fn e -> String.trim(e) end)
        |> Enum.at(0)
        |> String.upcase()

      case Announcements.Storage.delete(hash) do
        :ok ->
          "Template with ID **#{hash}** deleted"

        {:error, reason} ->
          message = "Error deleteing template #{hash}"
          Logger.error(message, reason: reason)
          message
      end
    end

    def help([]) do
      "Available **tmpl** subcommands are :
    - **add**: to add an announcement template (try _#{Application.fetch_env!(:o2m, :prefix)}tmpl help add_)
    - **list**: to list templates (try _#{Application.fetch_env!(:o2m, :prefix)}tmpl help list_)
    - **delete**: to delete a specific template (try _#{Application.fetch_env!(:o2m, :prefix)}tmpl help delete_)
    - **help**: to get this help message"
    end

    def help(args) do
      case Enum.join(args, " ") do
        "add" ->
          "Here is an example of \`add\` subcommand : \`\`\`#{Application.fetch_env!(:o2m, :prefix)}tmpl add #[show] just publish a new episode #[title], check it at #[url]\`\`\`"

        "list" ->
          "Here is an example of \`list\` subcommand : \`\`\`#{Application.fetch_env!(:o2m, :prefix)}tmpl list\`\`\`"

        "delete" ->
          "Here is an example of \`delete\` subcommand, using ID from list subcommand : \`\`\`#{Application.fetch_env!(:o2m, :prefix)}tmpl delete acfe\`\`\`"

        sub ->
          "Help for subcommand #{sub} not available"
      end
    end
  end

  defmodule Mo do
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

  defmodule Bt do
    @moduledoc """
    Bt module handles call to bind test command
    """
    import Discord

    @doc """
    Handle blind test init command
    """
    def init(msg, args) do
      adm = O2M.Application.from_env_to_int(:o2m, :bt_admin)
      guild_id = O2M.Application.from_env_to_int(:o2m, :guild)

      with :private <- channel_type(msg.channel_id),
           :member <- is_member(msg.author, adm, guild_id),
           :none <- BlindTest.process() do
        BlindTest.init(msg.attachments, msg.author, msg.channel_id, args)
      else
        :not_member ->
          "You do not have required permissions to init a new blind test"

        :public ->
          "Blind test can only be init in a private channel (and this message comes from a public one 🤦‍♀️)"

        {:one, _} ->
          {:ok, channel_id} = Game.channel_id()
          guild = Nostrum.Cache.GuildCache.get!(guild_id)

          "There is already a blind test in progress in channel #{channel(channel_id)} on guild **#{guild.name}**, destroy it first before creating a new one"

        {:error, reason} ->
          "Error, #{reason}"
      end
    end

    @doc """
    Handle blind test init command
    """
    def check(msg) do
      with :private <- channel_type(msg.channel_id),
           {:ok, {filename, guess_entries}} <- BlindTest.check(msg.attachments) do
        Nostrum.Api.create_message!(
          msg.channel_id,
          "✅ Syntax for playlist `#{filename}` checked : 👌"
        )

        Nostrum.Api.create_message!(
          msg.channel_id,
          "__Moving on to download checks__"
        )

        errors =
          Enum.reduce(guess_entries, 0, fn guess, acc ->
            with {:ok, stdout} <- Downloader.Yydl.get(guess.url),
                 [data_url | _] <- String.split(stdout, "\n") do
              start =
                Timex.Duration.to_time!(%Timex.Duration{
                  microseconds: 0,
                  megaseconds: 0,
                  seconds: 0
                })

              to =
                Timex.Duration.to_time!(%Timex.Duration{
                  microseconds: 0,
                  megaseconds: 0,
                  seconds: 1
                })

              case System.cmd("ffmpeg", [
                     "-y",
                     "-ss",
                     Time.to_string(start),
                     "-to",
                     Time.to_string(to),
                     "-i",
                     data_url,
                     "-c:a",
                     "libopus",
                     "-ac",
                     "1",
                     "-b:a",
                     "96K",
                     "-vbr",
                     "on",
                     "-frame_duration",
                     "20",
                     "-f",
                     "null",
                     "/dev/null"
                   ]) do
                {_stdout, 0} ->
                  acc

                {_stderr, _} ->
                  Nostrum.Api.create_message(
                    msg.channel_id,
                    "__Downloader checker update__: error getting raw data for url #{guess.url}"
                  )

                  acc + 1
              end
            else
              [] ->
                Nostrum.Api.create_message(
                  msg.channel_id,
                  "__Downloader checker update__: no data found for url #{guess.url}"
                )

                acc + 1

              {:error, _} ->
                Nostrum.Api.create_message(
                  msg.channel_id,
                  "__Downloader checker update__: error getting #{guess.url}"
                )

                acc + 1
            end
          end)

        if errors != 0,
          do:
            "❌ **#{errors} download error(s)** for #{length(guess_entries)} entries in playlist `#{filename}`",
          else: "✅ No download errors in playlist `#{filename}` 👌"
      else
        {:error, reason} ->
          "❌ there is an error in this playlist : **#{reason}**"

        :public ->
          "Blind test can only be checked in a private channel (and this message comes from a public one 🤦‍♀️)"
      end
    end

    @doc """
    Handle join commmand
    """
    def join(msg) do
      with {:one, _} <- BlindTest.process(),
           {:ok, _} <- BlindTest.check_channel_id(msg.channel_id) do
        case Game.add_player(msg.author.id) do
          {:ok, :added} ->
            # 👌
            Nostrum.Api.create_reaction(msg.channel_id, msg.id, %Nostrum.Struct.Emoji{
              name: Emojos.get(:joined)
            })

            :no_message

          {:ok, :duplicate} ->
            # 👌
            Nostrum.Api.create_reaction(msg.channel_id, msg.id, %Nostrum.Struct.Emoji{
              name: Emojos.get(:joined)
            })

            :no_message

          {:error, :not_transition} ->
            "You can only join a blind test **between two guesses**"
        end
      else
        {:error, channel_id} ->
          "Sorry but you can only interact with blind test in #{channel(channel_id)}"

        :none ->
          "Can't join a blind test since there is no blind test running 🤣"
      end
    end

    @doc """
    Handle leave commmand
    """
    def leave(msg) do
      with {:one, _} <- BlindTest.process(),
           {:ok, _} <- BlindTest.check_channel_id(msg.channel_id) do
        case Game.remove_player(msg.author.id) do
          {:ok, :removed} ->
            "User #{msg.author} quit the game... BOOOOOO !"

          {:error, :not_transition} ->
            "You can only leave a blind test **between two guesses**"

          {:error, :not_playing} ->
            "User #{msg.author} please **join a blind** test before leaving one 😛"
        end
      else
        {:error, channel_id} ->
          "Sorry but you can only interact with a blind test in #{channel(channel_id)}"

        :none ->
          "Can't leave a blind test since there is no blind test running 🙃"
      end
    end

    @doc """
    Handle players command
    """
    def players(msg) do
      guild_id = O2M.Application.from_env_to_int(:o2m, :guild)

      with {:one, _} <- BlindTest.process(),
           {:ok, _} <- BlindTest.check_channel_id(msg.channel_id) do
        {:ok, players_id} = Game.get_players()

        if MapSet.size(players_id) != 0 do
          {:ok, author_id} = Game.get_author()
          vocal_channel_id = O2M.Application.from_env_to_int(:o2m, :bt_vocal)
          me = Nostrum.Cache.Me.get()

          players_in_vocal =
            guild_id
            |> Nostrum.Cache.GuildCache.get!()
            |> Map.get(:voice_states)
            |> Enum.filter(fn v -> v.channel_id == vocal_channel_id end)
            |> Enum.filter(fn v -> v.user_id != me.id && v.user_id != author_id end)
            |> Enum.map(fn v -> v.user_id end)
            |> MapSet.new()

          list =
            Enum.reduce(
              MapSet.to_list(players_id),
              "**Player(s) in this session (#{MapSet.size(players_id)}) :**\n",
              fn elem, acc ->
                "#{acc}\n\t- #{mention(elem)}"
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
                fn elem, acc -> "#{acc}\n\t- #{mention(elem)}" end
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
                fn elem, acc -> "#{acc}\n\t- #{mention(elem)}" end
              )
            end

          Enum.join([list, missing_in_game, missing_in_vocal], "\n\n")
        else
          "There is no players yet in this session"
        end
      else
        {:error, channel_id} ->
          "Sorry but you can only interact with blind test in #{channel(channel_id)}"

        :none ->
          "Can't list players in a blind test since there is no a blind test running 🙃"
      end
    end

    @doc """
    Handle start command
    """
    def start(msg) do
      adm = O2M.Application.from_env_to_int(:o2m, :bt_admin)
      guild_id = O2M.Application.from_env_to_int(:o2m, :guild)

      with {:one, _} <- BlindTest.process(),
           :member <- is_member(msg.author, adm, guild_id),
           {:ok, _} <- BlindTest.check_channel_id(msg.channel_id) do
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

            :no_message

          {:error, :no_guess} ->
            "Sorry but there is no guess for this game"

          {:error, :vocal_not_ready} ->
            "Sorry but vocal channel is not ready"

          {:error, :no_players} ->
            "Sorry but I can't start a blind test without players... 🙃"

          {:error, :not_ready} ->
            "Sorry but blind test is not ready yet ⏳"

          {:error, :running} ->
            "Sorry but a blind test is already running 🎮"

          {:error, reason} ->
            reason
        end
      else
        {:error, channel_id} ->
          "Sorry but you can only interact with blind test in #{channel(channel_id)}"

        :none ->
          "Can't list start a blind test since there is no blind test running 🙃"

        :not_member ->
          "#{mention(msg.author.id)} do not have permission to start a blind test"
      end
    end

    @doc """
    Handle ranking command
    """
    def ranking(msg) do
      with {:one, _} <- BlindTest.process(),
           {:ok, _} <- BlindTest.check_channel_id(msg.channel_id) do
        case Game.get_ranking() do
          {:ok, message} ->
            message

          {:error, :no_ranking} ->
            "Sorry but there is no ranking (yet) in this blind test"
        end
      else
        {:error, channel_id} ->
          "Sorry but you can only interact with blind test in #{channel(channel_id)}"

        :none ->
          "Can't get scores for a blind test since there is no blind test running 🙃"
      end
    end

    @doc """
    Handle pass command
    """
    def pass(msg) do
      with {:one, _} <- BlindTest.process(),
           {:ok, _} <- BlindTest.check_channel_id(msg.channel_id),
           {:ok, players} <- Game.get_players(),
           true <- MapSet.member?(players, msg.author.id) do
        case Game.player_pass(msg.author.id) do
          {:ok, :passed} ->
            # ⏩
            Nostrum.Api.create_reaction(msg.channel_id, msg.id, %Nostrum.Struct.Emoji{
              name: Emojos.get(:passed)
            })

            :no_message

          {:ok, :skips} ->
            # ⏩
            Nostrum.Api.create_reaction(msg.channel_id, msg.id, %Nostrum.Struct.Emoji{
              name: Emojos.get(:passed)
            })

            "STOP THE COUNT, I skip this guess"

          {:ok, :already_passed} ->
            # 🖕
            Nostrum.Api.create_reaction(msg.channel_id, msg.id, %Nostrum.Struct.Emoji{
              name: Emojos.get(:already_passed)
            })

            :no_message

          {:error, :not_guessing} ->
            "You can only pass a track when **guessing one**"
        end
      else
        {:ok, channel_id} ->
          "Sorry but you can only interact with blind test in #{channel(channel_id)}"

        false ->
          "#{mention(msg.author.id)} join a game if you want to use this command..."

        :none ->
          "Can't pass a track in a blind test since there is no a blind test running  🙃"
      end
    end

    @doc """
    Handle status command
    """
    def status(_msg) do
      case BlindTest.status() do
        :none ->
          "No blind test running"

        status ->
          {:ok, channel_id} = Game.channel_id()

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
      end
    end

    @doc """
    Handle destroy command
    """
    def destroy(msg) do
      adm = O2M.Application.from_env_to_int(:o2m, :bt_admin)
      guild_id = O2M.Application.from_env_to_int(:o2m, :guild)

      with {:one, _} <- BlindTest.process(),
           :member <- is_member(msg.author, adm, guild_id),
           {:ok, _} <- BlindTest.check_channel_id(msg.channel_id) do
        BlindTest.destroy()
        Cache.clean()

        Nostrum.Api.create_message(
          msg.channel_id,
          embed: %Nostrum.Struct.Embed{
            :title => "Okay ! Time to clean up ! 🧹",
            :description => "It was a pleasure ! See you next time ! 💋",
            :color => Colors.get_color(:danger)
          }
        )

        :no_message
      else
        {:error, channel_id} ->
          "Sorry but you can only interact with blind test in #{channel(channel_id)}"

        :none ->
          "Can't destroy a blind test since there is no blind test running 🙃"

        :not_member ->
          "#{mention(msg.author.id)} do not have permission to destroy a blind test"
      end
    end

    @doc """
    Handle help message
    """
    def help() do
      "Available **bt** subcommands are :

    __Administration commands__ (requires privileges)

    - **init**: init a new blind test, message should be a private message to the bot with a `.csv` file attached to it (`csv format: youtube.com/link,artist,title`)
    - **start**: starts the blind test if ready, this message should be send in the dedicated blind test text channel
    - **destroy**: destroy the running blind test, this message should be send in the dedicated blind test text channel

    __Players commands__ (only in dedicated bind test text channel)

    - **join**: join a blind test (available only when in transition between two songs or before the blind test start)
    - **leave**: leave current blind test (available only when in transition between two songs or before the blind test start)
    - **players**: list all players for this session
    - **pass**: when guessing a song, ask for skipping current guess
    - **ranking**: list current ranking for this session
    - **status**: fetch blind test status

    __Party commands__
    - **party join**: join this party
    - **party leave**: leave this party
    - **party players**: list players in this party
    - **party overview**: get an overview of the current party
    - **party list**: list all the games for this party
    - **party get <ID>**: get data about a specific game
    - **party reset**: reset party data (admin)

    __Leaderboard commands__

    - **lboard top**: print top 15 leaderboard (admin)
    - **lboard set @user +<value>**: add value to @user score
    - **lboard set @user -<value>**: substract value to @user score
    - **lboard set @user =<value>**: set @user score to value
    - **lboard get**: get asking user score

    __Help commands__

    - **rules**: print rules and various informations about blind test
    - **help**: to get this help message
    - **check**: to check if a blindtest playlist is valid

    __How to guide__ : https://github.com/papey/o2m/wiki"
    end

    def rules() do
      "_Blind test rules_

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

      \t - both fields in the same message : 8 points
      \t - first field  found : 2 points
      \t - second field found : 3 points

      "
    end

    def lboard(_msg, []) do
      "Missing instruction for `lboard` subcommand"
    end

    def lboard(msg, ["top" | _]) do
      adm = O2M.Application.from_env_to_int(:o2m, :bt_admin)
      guild_id = O2M.Application.from_env_to_int(:o2m, :guild)

      case is_member(msg.author, adm, guild_id) do
        :member ->
          Leaderboard.top()
          |> Enum.with_index()
          |> Enum.reduce(
            "**Leaderboard (top 15)**",
            fn {{user, score}, index}, acc ->
              "#{acc}\n#{index + 1} | #{mention(user)} - **#{score}** point(s)#{if index + 1 <= 3,
                do: " - #{Map.get(Game.get_medals(), index + 1)}"}"
            end
          )

        :not_member ->
          "#{mention(msg.author.id)} do not have permission to get leaderboard top"
      end
    end

    def lboard(msg, ["set", _user, <<instruction::binary-size(1)>> <> points | _]) do
      adm = O2M.Application.from_env_to_int(:o2m, :bt_admin)
      guild_id = O2M.Application.from_env_to_int(:o2m, :guild)

      case is_member(msg.author, adm, guild_id) do
        :member ->
          case Integer.parse(points) do
            {val, _} ->
              [user | _] = msg.mentions

              case instruction do
                "=" ->
                  Leaderboard.set(user.id, val)
                  "#{Discord.mention(user.id)}'s score set to #{val}"

                "+" ->
                  {:ok, updated} = Leaderboard.delta(user.id, val, &Kernel.+/2)
                  "#{Discord.mention(user.id)}'s score updated to #{updated} (+#{val})"

                "-" ->
                  {:ok, updated} = Leaderboard.delta(user.id, val, &Kernel.-/2)
                  "#{Discord.mention(user.id)}'s score updated to #{updated} (-#{val})"

                _ ->
                  "Not a valid set instruction"
              end

            :error ->
              "#{points} is not a valid integer value"
          end

        :not_member ->
          "#{mention(msg.author.id)} do not have permission to set leaderboard score"
      end
    end

    def lboard(_msg, ["set" | _]) do
      "Missing arguments for `set` instruction"
    end

    def lboard(msg, ["get" | _]) do
      total = Leaderboard.get(msg.author.id)
      "Total for user #{mention(msg.author.id)} : #{if total == 0, do: "👌", else: total}"
    end

    def lboard(_msg, _) do
      "Unsupported `lboard` instruction"
    end

    def party(msg, ["reset" | _]) do
      adm = O2M.Application.from_env_to_int(:o2m, :bt_admin)
      guild_id = O2M.Application.from_env_to_int(:o2m, :guild)

      case Discord.is_member(msg.author, adm, guild_id) do
        :member ->
          Party.reset()
          "Party data cleared sucessfully 🙌"

        :not_member ->
          "#{mention(msg.author.id)} do not have permission to reset party data"
      end
    end

    def party(_msg, ["list" | _]) do
      case Party.list_games() do
        [] ->
          "No games yet in this party"

        results ->
          Enum.reduce(results, "**List of games for this party :**\n", fn {id, result}, acc ->
            "#{acc}\n\t- ID : #{id} | Name : #{result.name}"
          end)
      end
    end

    def party(_msg, ["overview" | _]) do
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
    end

    def party(_msg, ["get"]), do: "This command needs a game ID"

    def party(_msg, ["get", id | _]) do
      case Integer.parse(id) do
        {val, _} ->
          case Party.get_game(val) do
            [] ->
              "No game found for game ID #{id}"

            [{_id, game} | _] ->
              "Ranking for game **#{game.name}** :\n#{Game.generate_ranking(game.scores)}"
          end

        _ ->
          "Result ID must be a valid integer value (received #{id})"
      end
    end

    def party(msg, ["join" | _]) do
      Party.add_player(msg.author.id)

      # 👌
      Nostrum.Api.create_reaction(msg.channel_id, msg.id, %Nostrum.Struct.Emoji{
        name: Emojos.get(:joined)
      })

      :no_message
    end

    def party(msg, ["leave" | _]) do
      Party.remove_player(msg.author.id)

      "XOXO #{Discord.mention(msg.author.id)} 😗"
    end

    def party(_, ["players" | _]) do
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
    end

    def party(_, []) do
      "Missing instruction for party subcommand"
    end

    def party(_msg, input) do
      "**#{Enum.join(input, " ")}** is not a party subcommand 🙅"
    end

    def bam() do
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
    end

    @doc """
    Handle and route blind-test subcommands
    """
    def handle(sub, args, msg) do
      Logger.info("Blind test command received", sub: sub, message: msg.content)

      case sub do
        "init" ->
          init(msg, args)

        "join" ->
          join(msg)

        "leave" ->
          leave(msg)

        "players" ->
          players(msg)

        "start" ->
          start(msg)

        "ranking" ->
          ranking(msg)

        "status" ->
          status(msg)

        "pass" ->
          pass(msg)

        "destroy" ->
          destroy(msg)

        "help" ->
          help()

        "rules" ->
          rules()

        "lboard" ->
          lboard(msg, args)

        # Easter egg, only for Zblah request
        "bam" ->
          bam()

        "check" ->
          check(msg)

        "party" ->
          party(msg, args)

        _ ->
          "Sorry but subcommand **#{sub}** of command **bt** is not supported"
      end
    end
  end
end

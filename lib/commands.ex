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
      "Using prefix `#{prefix}` available commands are :
- mo : to interact with metalorgie website and database
- tmpl : to interact with announcement templates
- bt : to interact with blind tests (configured: **#{BlindTest.configured?()}**)
In order to get specific help for a command type `#{prefix}command help`"
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
      "Missing template for `add` subcommand"
    end

    # if args provided
    def add(args) do
      # get template from args
      [template | _] =
        Enum.join(args, " ") |> String.split("//") |> Enum.map(fn e -> String.trim(e) end)

      # get all keys
      keys = get_keys(template)

      # check if only mandatory/allowed keys are set
      case Announcements.valid?(keys, template) do
        true ->
          # if ok, use template
          case Announcements.Storage.put(template) do
            true ->
              "Template added succesfully"

            false ->
              "Template already exists"

            {:warning, message} ->
              message

            {:error, reason} ->
              Logger.error("Error while saving template to DETS file", reason: reason)
          end

        false ->
          # if not, fallback to a default one
          "Invalid template ensure all required keys are set (__mandatory keys : #{m2s()}__) and respect length limit (**#{
            Announcements.limit()
          } characters)**"
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
        Enum.join(args, " ")
        |> String.split("//")
        |> Enum.map(fn e -> String.trim(e) end)
        |> Enum.at(0)
        |> String.upcase()

      case Announcements.Storage.delete(hash) do
        :ok ->
          "Template deleted"

        {:error, reason} ->
          Logger.error("Error deleting template", reason: reason)
          "Error deleting template"
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
          "Here is an example of \`add\` subcommand : \`\`\`#{
            Application.fetch_env!(:o2m, :prefix)
          }tmpl add #[show] just publish a new episode #[title], check it at #[url]\`\`\`"

        "list" ->
          "Here is an example of \`list\` subcommand : \`\`\`#{
            Application.fetch_env!(:o2m, :prefix)
          }tmpl list\`\`\`"

        "delete" ->
          "Here is an example of \`delete\` subcommand, using id from list subcommand : \`\`\`#{
            Application.fetch_env!(:o2m, :prefix)
          }tmpl delete acfe\`\`\`"

        sub ->
          "Subcommand #{sub} not available"
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
        Enum.join(args, " ") |> String.split("//") |> Enum.map(fn e -> String.trim(e) end)

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
          "Here is an example of \`album\` subcommand : \`\`\`#{
            Application.fetch_env!(:o2m, :prefix)
          }mo album korn // follow the leader \`\`\`"

        "band" ->
          "Here is an example of \`band\` subcommand : \`\`\`#{
            Application.fetch_env!(:o2m, :prefix)
          }mo band korn\`\`\`"

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
    def init(msg) do
      adm = O2M.Application.from_env_to_int(:o2m, :bt_admin)
      guild_id = O2M.Application.from_env_to_int(:o2m, :guild)

      with :private <- channel_type(msg.channel_id),
           :member <- is_member(msg.author, adm, guild_id),
           :none <- BlindTest.process() do
        BlindTest.init(msg.attachments, msg.author, msg.channel_id)
      else
        :not_member ->
          "User do not have permission to init a blind test"

        :public ->
          "Blind test can only be init in a private channel"

        {:one, _} ->
          {:ok, channel_id} = Game.channel_id()
          guild = Nostrum.Cache.GuildCache.get!(guild_id)

          "There is already a blind test in progress in channel #{channel(channel_id)} on guild **#{
            guild.name
          }**, destroy it first before creating a new one"

        {:error, reason} ->
          "Error #{reason}"
      end
    end

    @doc """
    Handle blind test init command
    """
    def check(msg) do
      with :private <- channel_type(msg.channel_id),
           {:ok, filename} <- BlindTest.check(msg.attachments) do
        "✅ Playlist #{filename} checked"
      else
        {:error, reason} ->
          "❌ Error #{reason}"

        :public ->
          "Blind test can only be checked in a private channel"
      end
    end

    @doc """
    Handle join commmand
    """
    def join(msg) do
      with {:one, _} <- BlindTest.process(),
           {:ok, channel_id} = Game.channel_id() do
        if msg.channel_id == channel_id do
          case Game.add_player(msg.author.id) do
            {:ok, :added} ->
              # 👌
              Nostrum.Api.create_reaction(channel_id, msg.id, %Nostrum.Struct.Emoji{
                name: Emojos.get(:joined)
              })

              :no_message

            {:ok, :duplicate} ->
              # 🚫
              Nostrum.Api.create_reaction(channel_id, msg.id, %Nostrum.Struct.Emoji{
                name: Emojos.get(:duplicate_join)
              })

              :no_message

            {:error, :not_transition} ->
              "You can only join a blind test between two guesses"
          end
        else
          "Sorry but you can only interact with blind test in #{channel(channel_id)}"
        end
      else
        :none ->
          "Can't join a blind test since there is no blind test running"
      end
    end

    @doc """
    Handle leave commmand
    """
    def leave(msg) do
      with {:one, _} <- BlindTest.process(),
           {:ok, channel_id} = Game.channel_id() do
        if msg.channel_id == channel_id do
          case Game.remove_player(msg.author.id) do
            {:ok, :removed} ->
              "User #{msg.author} quit the game... BOOOOOO !"

            {:error, :not_transition} ->
              "You can only leave a blind test between two guesses"

            {:error, :not_playing} ->
              "User #{msg.author} please join a blind test before leaving one"
          end
        else
          "Sorry but you can only interact with blind test in #{channel(channel_id)}"
        end
      else
        :none ->
          "Can't leave a blind test since there is no blind test running"
      end
    end

    @doc """
    Handle players command
    """
    def players(msg) do
      guild_id = O2M.Application.from_env_to_int(:o2m, :guild)

      with {:one, _} <- BlindTest.process(),
           {:ok, channel_id} = Game.channel_id() do
        if msg.channel_id == channel_id do
          {:ok, players_id} = Game.get_players()

          if MapSet.size(players_id) != 0 do
            {:ok, author_id} = Game.get_author()
            vocal_channel_id = O2M.Application.from_env_to_int(:o2m, :bt_vocal)
            me = Nostrum.Cache.Me.get()

            players_in_vocal =
              Nostrum.Cache.GuildCache.get!(guild_id)
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
              cond do
                MapSet.subset?(players_in_vocal, players_id) ->
                  "**Every member in vocal channel is in game**"

                true ->
                  MapSet.difference(players_in_vocal, players_id)
                  |> MapSet.to_list()
                  |> Enum.reduce(
                    "**Missing player(s) from vocal channel :**\n",
                    fn elem, acc -> "#{acc}\n\t- #{mention(elem)}" end
                  )
              end

            missing_in_vocal =
              cond do
                MapSet.subset?(players_id, players_in_vocal) ->
                  "**Every player is connected to the vocal channel**"

                true ->
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
          "Sorry but you can only interact with blind test in #{channel(channel_id)}"
        end
      else
        :none ->
          "Can't list players in a blind test since there is no a blind test running"
      end
    end

    @doc """
    Handle start command
    """
    def start(msg) do
      adm = O2M.Application.from_env_to_int(:o2m, :bt_admin)
      guild_id = O2M.Application.from_env_to_int(:o2m, :guild)

      with {:one, _} <- BlindTest.process(),
           :member <- is_member(msg.author, adm, guild_id) do
        {:ok, channel_id} = Game.channel_id()

        if msg.channel_id == channel_id do
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

            {:error, :vocal_not_ready} ->
              "Sorry but vocal channel is not ready"

            {:error, :no_players} ->
              "Sorry but I can't start a blind test without players..."

            {:error, :not_ready} ->
              "Sorry but blind test is not ready yet"

            {:error, :running} ->
              "Sorry but a blind test is already running"

            {:error, reason} ->
              reason
          end
        end
      else
        :none ->
          "Can't list players in a blind test since there is no blind test running"

        :not_member ->
          "User do not have permission to start a blind test"
      end
    end

    @doc """
    Handle ranking command
    """
    def ranking(msg) do
      with {:one, _} <- BlindTest.process() do
        {:ok, channel_id} = Game.channel_id()

        if msg.channel_id == channel_id do
          case Game.get_ranking() do
            {:ok, message} ->
              message

            {:error, :no_ranking} ->
              "Sorry but there is no ranking (yet) in this blind test"
          end
        else
          "Sorry but you can only interact with blind test in #{channel(channel_id)}"
        end
      else
        :none ->
          "Can't get scores for a blind test since there is no blind test running"
      end
    end

    @doc """
    Handle pass command
    """
    def pass(msg) do
      with {:one, _} <- BlindTest.process(),
           {:ok, channel_id} <- Game.channel_id(),
           {:ok, players} <- Game.get_players(),
           true <- MapSet.member?(players, msg.author.id) do
        "A blind test is currently running at #{channel(channel_id)}"

        if msg.channel_id == channel_id do
          case Game.player_pass(msg.author.id) do
            {:ok, :passed} ->
              # ⏩
              Nostrum.Api.create_reaction(channel_id, msg.id, %Nostrum.Struct.Emoji{
                name: Emojos.get(:passed)
              })

              :no_message

            {:ok, :skips} ->
              # ⏩
              Nostrum.Api.create_reaction(channel_id, msg.id, %Nostrum.Struct.Emoji{
                name: Emojos.get(:passed)
              })

              "STOP THE COUNT, I skip this guess"

            {:ok, :already_passed} ->
              # 🖕
              Nostrum.Api.create_reaction(channel_id, msg.id, %Nostrum.Struct.Emoji{
                name: Emojos.get(:already_passed)
              })

              :no_message

            {:error, :not_guessing} ->
              "You can only pass a track when guessing one"
          end
        else
          "Sorry but you can only interact with blind test in #{channel(channel_id)}"
        end
      else
        false ->
          "#{mention(msg.author.id)} join a game if you want to use this command..."

        :none ->
          "Can't pass a track in a blind test since there is no a blind test running"
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
           :member <- is_member(msg.author, adm, guild_id) do
        {:ok, channel_id} = Game.channel_id()

        if msg.channel_id == channel_id do
          BlindTest.destroy()
          Cache.clean()

          Nostrum.Api.create_message!(
            msg.channel_id,
            embed: %Nostrum.Struct.Embed{
              :title => "Okay ! Time to clean up ! 🧹",
              :description => "It was a pleasure ! See you next time ! 💋",
              :color => Colors.get_color(:danger)
            }
          )
        else
          "Sorry but you can only interact with blind test in #{channel(channel_id)}"
        end
      else
        :none ->
          "Can't destroy a blind test since there is no blind test running"

        :not_member ->
          "User do not have permission to destroy a blind test"
      end
    end

    @doc """
    Handle help message
    """
    def help() do
      "Available **bt** subcommands are :

    __Administration commands__ (requires privileges)

    - **init**: inits a new blind test, this message should be a private message to the bot with a `.csv` attached to it (`csv format: youtube.com/link,artist,title`)
    - **start**: starts the blind test if ready, this message should be send in the dedicated blind test text channel
    - **destroy**: destroy the running blind test, this message should be send in the dedicated blind test text channel\n

    __Players commands__ (only in dedicated bind test text channel)

    - **join**: join a blind test (available only when in transition between two songs or before the blind test start)
    - **leave**: leave current blind test (available only when in transition between two songs or before the blind test start)
    - **players**: list all players for this session
    - **pass**: when guessing a song, ask for skipping current guess
    - **ranking**: list current ranking for this session
    - **status**: fetch blind test status

    __Leaderboard commands__

    - **lboard top**: print top 15 leaderboard (admin)
    - **lboard set @user +<value>**: add value to @user score
    - **lboard set @user -<value>**: substract value to @user score
    - **lboard set @user =<value>**: set @user score to value
    - **lboard get**: get asking user score

    __Help commands__

    - **rules**: print rules and various informations about blind test
    - **help**: to get this help message
    - **check**: to check if a blindtest playlist is valid, this message should be a private message to the bot with a `.csv` file attached to it (`csv format: youtube.com/link,artist,title`)

    __How to guide__ : https://github.com/papey/o2m/wiki"
    end

    def rules() do
      "_Blind test rules_

      __Reaction emojis__

      When joining :
      \t #{Emojos.get(:joined)}: message author joined the game
      \t #{Emojos.get(:duplicate_join)}: message author already joined the game

      When guessing :
      \t answer validation :
      \t\t #{Emojos.get(:both)}: message author found both artist and title
      \t\t #{Emojos.get(:artist)}: message author found the artist
      \t\t #{Emojos.get(:title)}: message author found the title
      \t\t #{Emojos.get(:already)}: message author found an answer, but too late !
      \t\t if no reactions added user answer is wrong
      \t pass
      \t\t #{Emojos.get(:passed)}: message author passed the current guess
      \t\t #{Emojos.get(:already_passed)}: message author already passed the current guess

      __Games points__

      Only the first get the points !

      \t - artist and title found in the same message : 8 points
      \t - artist found : 2 points
      \t - title found : 3 points

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
              "#{acc}\n#{index + 1} | #{Discord.mention(user)} - **#{score}** point(s)#{
                if index + 1 <= 3,
                  do: " - #{Map.get(Game.get_medals(), index + 1)}"
              }"
            end
          )

        :not_member ->
          "User do not have permission to get leaderboard top"
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
          "User do not have permission to set leaderboard score"
      end
    end

    def lboard(_msg, ["set" | _]) do
      "Missing arguments for `set` instruction"
    end

    def lboard(msg, ["get" | _]) do
      total = Leaderboard.get(msg.author.id)
      "Total for user #{Discord.mention(msg.author.id)} : #{if total == 0, do: "👌", else: total}"
    end

    def lboard(_msg, [_]) do
      "Unsupported `lboard` instruction"
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
          init(msg)

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

        _ ->
          "Sorry but subcommand **#{sub}** of command **bt** is not supported"
      end
    end
  end
end

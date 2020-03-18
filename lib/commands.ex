defmodule O2M.Commands do
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
          "Sorry but subcommand **#{sub}** of command **mo** is not supported"
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
      [hash | _] =
        Enum.join(args, " ") |> String.split("//") |> Enum.map(fn e -> String.trim(e) end)

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
end

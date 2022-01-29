defmodule O2M.Commands.Tmpl do
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
    "Missing template for `add` subcommand"
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
        Logger.error("Error when deleting template", reason: reason)
        "**Error**: _#{reason}_"
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

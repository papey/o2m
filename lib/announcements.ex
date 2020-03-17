defmodule Announcements do
  @moduledoc """
  Messages is used to generate messages used by Jobs from custom user defined templates
  """

  @mandatory MapSet.new(["title", "show", "url"])

  @default "#[show] - #[title] - #[url]"

  @charlimit 200

  require Logger

  @doc """
  Export char limit using a simple function
  """
  def limit do
    @charlimit
  end

  @doc """
  Get default value from end
  """
  def get_default() do
    Application.fetch_env!(:o2m, :default_message)
  end

  @doc """
  Get keys from placeholders

  ## Examples
      iex> get_keys("#[key])
      #MapSet<["key"]>

  """
  def get_keys(template) do
    # get all set keys from placeholders in template
    Regex.scan(~r/#\[(\w+)\]/, template)
    |> Enum.reduce(MapSet.new(), fn [_, e], acc -> MapSet.put(acc, e) end)
  end

  @doc """
  Replace placeholders by value to create an annoucement

  ## Examples

      iex> replace(MapSet.new("title"), "#[title]", %{"title" => "itworks"})
      "itworks"
  """
  def replace(keys, template, data) do
    Enum.reduce(keys, template, fn e, acc -> String.replace(acc, "#[#{e}]", Map.get(data, e)) end)
  end

  @doc """
  Valid will check if a set of keys contains mandatory keys
  """
  def valid?(keys, template) do
    MapSet.equal?(@mandatory, keys) && String.length(template) <= @charlimit
  end

  @doc """
  Present mandatory place holders as a string
  """
  def m2s() do
    Enum.reduce(@mandatory, "", fn e, acc -> "#{acc} #[#{e}]" end) |> String.trim()
  end

  @doc """
  Generate a string using a template with placeholders and data

  ## Examples

      iex> generate("This is a [#title], for a #[show] at #[url]", %{"title" => title, "show" => "show", "url" => "url"})
      "This is a title, for a show at url"
  """
  def generate(template, data) do
    # get all keys
    keys = get_keys(template)

    # check if only mandatory/allowed keys are set
    case valid?(keys, template) do
      true ->
        # if ok, use template
        replace(keys, template, data)

      false ->
        # if not, fallback to a default one
        Logger.warn("Invalid template, fallback to default", template: template)
        replace(@mandatory, @default, data)
    end
  end

  @doc """
  Roll a random template from storage if nothing found, fallback to default
  """
  def roll do
    # fetch all templates from storage
    case Announcements.Storage.get_all() do
      # if nothing is found
      [] ->
        # use the default one
        @default

      # if not, random and take the first element
      templates ->
        {_, template} = Enum.random(templates)
        template
    end
  end

  @doc """
  Announce is used to roll a template and replace data to create a ready to go message
  """
  def announce(metadata) do
    generate(roll(), metadata)
  end

  defmodule Storage do
    @moduledoc """
    Storage is a module used to interact with DETS to store custom templates
    """

    @doc """
    Genkey is used to generate key from a template
    """

    @limit 10

    def genkey(template) do
      :crypto.hash(:md5, template) |> Base.encode16() |> String.slice(0..3)
    end

    @doc """
    Store template if checks pass
    """
    def put(template) do
      case(length(get_all())) do
        l when l < @limit ->
          path = to_charlist(Application.fetch_env!(:o2m, :tmpl_dets))
          {:ok, table} = :dets.open_file(path, type: :set)
          ret = :dets.insert_new(table, {genkey(template), template})
          :dets.close(table)
          ret

        _ ->
          Logger.warn(
            "Template not added to storage, you've reached the limit of #{@limit} templates",
            template: template
          )

          {:warning, "Template not added, storage limit (#{@limit} reached"}
      end
    end

    @doc """
    List all stored templates
    """
    def get_all() do
      path = to_charlist(Application.fetch_env!(:o2m, :tmpl_dets))
      {:ok, table} = :dets.open_file(path, type: :set)
      objs = :dets.match_object(table, {:"$1", :"$2"})
      :dets.close(table)
      objs
    end

    @doc """
    Remove a specific stored template
    """
    def delete(hash) do
      path = to_charlist(Application.fetch_env!(:o2m, :tmpl_dets))
      {:ok, table} = :dets.open_file(path, type: :set)
      ret = :dets.delete(table, hash)
      :dets.close(table)
      ret
    end
  end
end

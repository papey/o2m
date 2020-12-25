defmodule Cache do
  @moduledoc """
  Module used to get data from filesystem to data playable by Nostrum
  """

  @doc """
  Get a file using it's id

  Returns a file binary containing file data
  """
  def path(uuid) do
    cache = Application.fetch_env!(:o2m, :bt_cache) |> String.trim_trailing("/")

    file =
      File.ls!(cache)
      |> Enum.find(&String.contains?(uuid, Path.basename(&1, Path.extname(&1))))

    case file do
      nil -> {:error, "File with ID #{uuid} not found"}
      f -> {:ok, "#{cache}/#{f}"}
    end
  end

  @doc """
  Cleans a cache directory

  Removes all files in cache directory
  """
  def clean() do
    cache = Application.fetch_env!(:o2m, :bt_cache) |> String.trim_trailing("/")

    files = File.ls!(cache)

    for file <- files, do: File.rm!("#{cache}/#{file}")
  end
end

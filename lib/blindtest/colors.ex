defmodule Colors do
  @moduledoc """
  Fetch colors for various embed Discord message
  """

  @colors %{
    :info => 39372,
    :success => 51281,
    :warning => 16_746_496,
    :danger => 13_369_344
  }

  @doc """
  Map colors to atoms

  Return decimal color associated
  """
  def get_color(kind) do
    Map.get(@colors, kind, 0)
  end
end

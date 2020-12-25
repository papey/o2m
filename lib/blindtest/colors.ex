defmodule Colors do
  @moduledoc """
  Fetch colors for various embed Discord message
  """

  @doc """
  Map colors to atoms

  Return decimal color associated
  """
  def get_color(kind) do
    case kind do
      :info -> 39372
      :success -> 51281
      :warning -> 16_746_496
      :danger -> 13_369_344
      _ -> 0
    end
  end
end

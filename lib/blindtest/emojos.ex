defmodule Emojos do
  @moduledoc """
  Module used to get emojos and emojos
  """

  @emojos %{
    :artist => "🎤",
    :no => "🚫",
    :already => "⏰",
    :title => "💿",
    :both => "🏆",
    :passed => "⏩",
    :already_passed => "🖕",
    :joined => "👌",
    :duplicate_join => "🚫"
  }

  def get(name) do
    Map.get(@emojos, name, "")
  end
end

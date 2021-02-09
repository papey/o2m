defmodule Emojos do
  @moduledoc """
  Module used to get emojos and emojos
  """

  @emojos %{
    :f1 => "1️⃣",
    :f2 => "2️⃣",
    :no => "🚫",
    :already => "⏰",
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

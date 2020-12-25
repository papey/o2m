defmodule YoutubeTest do
  use ExUnit.Case
  doctest Youtube

  test "with weird @Bacteries URL" do
    url = "https://www.youtube.com/watch?v=OMk2dHRYIxE&t=216s&ab_channel=Verdun"

    {:ok, 216} = Youtube.get_timestamp(url)
  end
end

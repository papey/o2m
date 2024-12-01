defmodule MetalorgieTest do
  use ExUnit.Case
  doctest Metalorgie

  test "get_band for band `korn`" do
    {:ok, %{url: url}} = Metalorgie.get_band(["korn"])
    assert url == "http://www.metalorgie.com/groupe/Korn"
  end

  test "get_band for band `opeth`" do
    {:ok, result} = Metalorgie.get_band(["opeth"])
    assert result[:desc] == "Les plus atypiques du death suédois"
  end

  test "get_band for band `nopnop`" do
    {:error, message} = Metalorgie.get_band(["nopnop"])
    assert message == "No band with name **nopnop** found"
  end

  test "get_albums for band `iron maiden`" do
    {:ok, result} = Metalorgie.get_albums(["iron", "maiden"])
    assert length(result) >= 10
  end
end

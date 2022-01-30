defmodule GameTest do
  use ExUnit.Case
  doctest Game

  test "verify_answer with multiple input data" do
    ge = %BlindTest.GuessEntry{
      f1s: ["rage against the machine", "ratm"],
      f2s: ["killing in the name"]
    }

    answers = [
      {"notvalid", :wrong},
      {"deep purple", :wrong},
      {"rage machine against", :wrong},
      {"ratm", :f1},
      {"rage afainst the machine", :f1},
      {"killing in the name", :f2},
      {"killing i the nam", :f2},
      {"rulzofnine", :wrong},
      {"ratm killing in the name", :both},
      {"rage against the machine killing in the name", :both},
      {"killing in the name ratm", :both}
    ]

    for {input, status} <- answers do
      assert Game.verify_answer(ge, input) == status
    end
  end
end

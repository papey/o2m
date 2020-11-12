defmodule BlindTestTest do
  use ExUnit.Case
  doctest BlindTest

  test "parse_csv file with DOS line returns" do
    content =
      "https://youtu.be/iqrMFNMgVS0?t=114,gojira,another world\r\nhttps://youtu.be/75Mw8r5gW8E,eskimo callboy,hypa hypa"

    {:ok, parsed} = BlindTest.parse_csv(content)

    assert length(parsed) == 2
  end

  test "parse_csv file with ; as separator" do
    content =
      "https://youtu.be/iqrMFNMgVS0?t=114;gojira;another world\nhttps://youtu.be/75Mw8r5gW8E;eskimo callboy;hypa hypa"

    {:ok, parsed} = BlindTest.parse_csv(content)

    assert length(parsed) == 2
  end

  test "parse_csv file with a comment" do
    content =
      "# this is a comment\nhttps://youtu.be/iqrMFNMgVS0?t=114;gojira;another world\nhttps://youtu.be/75Mw8r5gW8E;eskimo callboy;hypa hypa"

    {:ok, parsed} = BlindTest.parse_csv(content)

    assert length(parsed) == 2
  end

  test "parse_csv return an error when url is not a youtube one" do
    content = "https://youteube.be/irqdmrjvQ,invalid,invalid"

    {:error, _} = BlindTest.parse_csv(content)
  end

  test "parse_csv return when an entry is missing" do
    content =
      "https://youtu.be/iqrMFNMgVS0?t=114,gojira\r\nhttps://youtu.be/75Mw8r5gW8E,eskimo callboy,hypa hypa"

    {:error, _} = BlindTest.parse_csv(content)
  end

  test "verify_answer with multiple input data" do
    ge = %BlindTest.GuessEntry{
      artists: ["rage against the machine", "ratm"],
      titles: ["killing in the name"]
    }

    answers = [
      {"notvalid", :wrong},
      {"deep purple", :wrong},
      {"rage machine against", :wrong},
      {"ratm", :artist},
      {"rage afainst the machine", :artist},
      {"killing in the name", :title},
      {"killing i the nam", :title},
      {"rulzofnine", :wrong},
      {"ratm killing in the name", :both},
      {"rage against the machine killing in the name", :both},
      {"killing in the name ratm", :both}
    ]

    for {input, status} <- answers do
      assert BlindTest.verify_answer(ge, input) == status
    end
  end
end

defmodule BlindTestTest do
  use ExUnit.Case
  doctest BlindTest

  test "parse_csv file with DOS line returns" do
    content =
      "https://youtu.be/iqrMFNMgVS0?t=114,gojira,another world\r\nhttps://youtu.be/75Mw8r5gW8E,eskimo callboy,hypa hypa"

    {:ok, {_conf, parsed}} = BlindTest.parse_csv(content)

    assert length(parsed) == 2
  end

  test "parse_csv file with ; as separator" do
    content =
      "https://youtu.be/iqrMFNMgVS0?t=114;gojira;another world\nhttps://youtu.be/75Mw8r5gW8E;eskimo callboy;hypa hypa"

    {:ok, {_conf, parsed}} = BlindTest.parse_csv(content)

    assert length(parsed) == 2
  end

  test "parse_csv file with a comment" do
    content =
      "# this is a comment\nhttps://youtu.be/iqrMFNMgVS0?t=114;gojira;another world\nhttps://youtu.be/75Mw8r5gW8E;eskimo callboy;hypa hypa"

    {:ok, {_conf, parsed}} = BlindTest.parse_csv(content)

    assert length(parsed) == 2
  end

  test "parse_csv return an error when url is not a youtube one" do
    content = "https://youteube.be/irqdmrjvQ,invalid,invalid"

    {:error, _} = BlindTest.parse_csv(content)
  end

  test "parse_csv with custom directive return a config map" do
    content =
      "!customize,f1:=\"field1\",f2   :=field2,guess_duration:=   20         ,transition_duration:=2"

    {:ok, {conf, _parsed}} = BlindTest.parse_csv(content)
    assert conf.f1 == "field1"
    assert conf.f2 == "field2"
    assert conf.guess_duration == 20
    assert conf.transition_duration == 2
  end

  test "parse_csv return when an entry is missing" do
    content =
      "https://youtu.be/iqrMFNMgVS0?t=114,gojira\r\nhttps://youtu.be/75Mw8r5gW8E,eskimo callboy,hypa hypa"

    {:error, _} = BlindTest.parse_csv(content)
  end

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
      assert BlindTest.verify_answer(ge, input) == status
    end
  end
end

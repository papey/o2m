defmodule Party do
  use Agent

  defstruct counter: 1, games: %{}, players: MapSet.new()

  defmodule GameResult do
    defstruct name: "", scores: %{}
  end

  def start_link() do
    Agent.start_link(fn -> %__MODULE__{} end, name: __MODULE__)
  end

  def reset() do
    Agent.update(__MODULE__, fn _ -> %__MODULE__{} end)
  end

  def add_game(game) do
    Agent.update(__MODULE__, fn party ->
      %{party | counter: party.counter + 1, games: Map.put(party.games, party.counter + 1, game)}
    end)
  end

  def list_games() do
    Agent.get(__MODULE__, &Enum.to_list(&1.games))
  end

  def get_game(id) do
    Agent.get(__MODULE__, fn party ->
      Enum.filter(party.games, fn {key, _data} -> key == id end)
    end)
  end

  def add_player(pid) do
    if BlindTest.process() != :none do
      Game.add_player(pid)
    end

    Agent.update(__MODULE__, fn party ->
      %{party | players: MapSet.put(party.players, pid)}
    end)
  end

  def list_players() do
    Agent.get(__MODULE__, &MapSet.to_list(&1.players))
  end

  def remove_player(pid) do
    Agent.update(__MODULE__, fn party ->
      %{party | players: MapSet.delete(party.players, pid)}
    end)
  end
end

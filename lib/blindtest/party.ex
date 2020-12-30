defmodule Party do
  use Agent

  @init {1, %{}}

  defmodule Game do
    defstruct name: "", scores: %{}
  end

  def start_link() do
    Agent.start_link(fn -> @init end, name: __MODULE__)
  end

  def reset() do
    Agent.update(__MODULE__, fn _ -> @init end)
  end

  def add(game) do
    Agent.update(__MODULE__, fn {counter, games} ->
      {counter + 1, Map.put(games, counter, game)}
    end)
  end

  def list() do
    Agent.get(__MODULE__, fn {_, games} -> games end)
    |> Enum.to_list()
  end

  def get(id) do
    Agent.get(__MODULE__, fn {_, games} ->
      Enum.filter(games, fn {key, _data} -> key == id end)
    end)
  end
end

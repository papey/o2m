defmodule Leaderboard do
  @moduledoc """
  Interact with the leaderboard stored in dets file
  """

  @top 15

  def set(id, points) do
    path = to_charlist(Application.fetch_env!(:o2m, :bt_lboard_dets))

    {:ok, table} = :dets.open_file(path, type: :set)
    ret = :dets.insert(table, {id, points})
    :dets.close(table)

    ret
  end

  def delta(id, points, fun) do
    old = get(id)

    path = to_charlist(Application.fetch_env!(:o2m, :bt_lboard_dets))
    {:ok, table} = :dets.open_file(path, type: :set)

    ret =
      case fun.(old, points) do
        x when x > 0 ->
          {:dets.insert(table, {id, fun.(old, points)}), x}

        _ ->
          {:dets.insert(table, {id, 0}), 0}
      end

    :dets.close(table)

    ret
  end

  def get(id) do
    path = to_charlist(Application.fetch_env!(:o2m, :bt_lboard_dets))
    {:ok, table} = :dets.open_file(path, type: :set)
    ret = :dets.lookup(table, id)
    :dets.close(table)

    case ret do
      [] ->
        0

      [{_id, val} | _] ->
        val
    end
  end

  def update(scores) do
    path = to_charlist(Application.fetch_env!(:o2m, :bt_lboard_dets))
    {:ok, table} = :dets.open_file(path, type: :set)

    Enum.filter(scores, fn {_uid, val} -> val != 0 end)
    |> Enum.map(fn {id, points} ->
      old =
        case :dets.lookup(table, id) do
          [] -> 0
          [{_, val}] -> val
        end

      :dets.insert(table, {id, old + points})
    end)

    :dets.close(table)
  end

  def top() do
    path = to_charlist(Application.fetch_env!(:o2m, :bt_lboard_dets))
    {:ok, table} = :dets.open_file(path, type: :set)
    scores = :dets.match_object(table, {:"$1", :"$2"})
    sorted = Enum.sort(scores, fn {_id1, v1}, {_id2, v2} -> v1 > v2 end)
    :dets.close(table)
    sorted |> Enum.take(@top)
  end
end

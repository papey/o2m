# Since it was much clever than my first solution, it's taken from
# https://github.com/lexmag/elixir/commit/57758b36a2eb9223a0bce12379bc000231cae841#diff-8d55c1eaccd5de7586d5dfbdf19e8f31e95e566f3c609ddb93bbb703879807d0R1459

defmodule Levenshtein do
  def distance(source, source), do: 0

  def distance(source, <<>>), do: String.length(source)

  def distance(<<>>, target), do: String.length(target)

  def distance(source, target) do
    source = String.graphemes(source)
    target = String.graphemes(target)
    distlist = 0..Kernel.length(target) |> Enum.to_list()
    do_distance(source, target, distlist, 1)
  end

  defp do_distance([], _, distlist, _), do: List.last(distlist)

  defp do_distance([src_hd | src_tl], target, distlist, step) do
    distlist = distlist(target, distlist, src_hd, [step], step)
    do_distance(src_tl, target, distlist, step + 1)
  end

  defp distlist([], _, _, new_distlist, _), do: Enum.reverse(new_distlist)

  defp distlist(
         [target_hd | target_tl],
         [distlist_hd | distlist_tl],
         grapheme,
         new_distlist,
         last_dist
       ) do
    diff = if target_hd != grapheme, do: 1, else: 0
    # min(insert, remove, replace)
    min = min(min(last_dist + 1, hd(distlist_tl) + 1), distlist_hd + diff)
    distlist(target_tl, distlist_tl, grapheme, [min | new_distlist], min)
  end
end

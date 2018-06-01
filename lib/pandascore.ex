defmodule Panda do
@moduledoc """
Documentation for Panda.
"""

@doc """
Hello world.

## Examples

iex> Panda.hello
:world

"""

defp ok({:ok, result}), do: result

# Part1: Upcoming matches
def upcoming_matches do
  # API sorts upcoming by begin_date (descending order) by default
  HTTPotion.get("https://api.pandascore.co/matches/upcoming?sort=begin_at&page=1&per_page=5", [headers: ["Authorization": "Bearer fLcMqHoc8Yb0co-87sjZkdwY3g7gUX6DD6BFrxJbIQocb2RB2xc"]]) |> Map.get(:body) |> Poison.Parser.parse |> ok |> Enum.map(fn(e) -> %{"begin_at" => e["begin_at"], "id" => e["id"], "name" => e["name"]} end)
end


# Part2: Basic odds
# How odds are computed: this is a very simplistic model where we look at past matches within the current series
# Probability of team 1 winning = ((success rate of team 1 in the current serie + (1 - success rate of team 2 in the current serie)) * 0.9 + alea 
# alea is defined by events that do not relate directly to teams performance, but still exist in real life. Here it is a random number between 0 and 0.1. 
# Note that this alea should be somewhat fixed so that odds to not vary from one call to another... something that would need to be improved here
defp get_data_for_team(serie_id, team_id, page_n) do
  HTTPotion.get("https://api.pandascore.co/series/" <> to_string(serie_id) <> "/matches?team_id=" <> to_string(team_id) <> "&filter[finished]=true&page=" <> to_string(page_n), [headers: ["Authorization": "Bearer fLcMqHoc8Yb0co-87sjZkdwY3g7gUX6DD6BFrxJbIQocb2RB2xc"]]) |> Map.get(:body) |> Poison.Parser.parse |> ok |> Enum.filter(fn(m) -> Map.get(m, "winner") != nil end)
end

defp get_all_data_for_team(serie_id, team_id, current_data, page_n) when length(current_data) <= 0 do
  current_data
end

defp get_all_data_for_team(serie_id, team_id, current_data, page_n) do
  current_data ++ get_all_data_for_team(serie_id, team_id, get_data_for_team(serie_id, team_id, page_n), page_n + 1)
end

def get_matches_data_for_team_in_serie(serie_id, team_id) do
  get_all_data_for_team(serie_id, team_id, get_data_for_team(serie_id, team_id, 1), 2)
end

def match_data(match_id) do
  HTTPotion.get("https://api.pandascore.co/matches/" <> to_string(match_id), [headers: ["Authorization": "Bearer fLcMqHoc8Yb0co-87sjZkdwY3g7gUX6DD6BFrxJbIQocb2RB2xc"]]) |> Map.get(:body) |> Poison.Parser.parse |> ok
end

def odds_for_match(match_id) do
  match_info = match_data(match_id)
  opponent1 = Map.get(Enum.at(Map.get(match_info, "opponents"), 0), "opponent")
  opponent2 = Map.get(Enum.at(Map.get(match_info, "opponents"), 1), "opponent")
  serie_id = Map.get(match_info, "serie_id")

  id_team1 = Map.get(opponent1, "id")
  matches_data_team1 = get_matches_data_for_team_in_serie(serie_id, id_team1) |> Enum.filter(fn(m) -> Map.get(m, "winner") != nil end)
  pct_win_team1 = Enum.reduce(matches_data_team1, 0, fn(m, acc) ->  if(Map.get(Map.get(m, "winner"), "id") == id_team1) do acc+1 else acc end end) / length(matches_data_team1)

  id_team2 = Map.get(opponent2, "id")
  matches_data_team2 = get_matches_data_for_team_in_serie(serie_id, id_team2) |> Enum.filter(fn(m) -> Map.get(m, "winner") != nil end)
  pct_win_team2 = Enum.reduce(matches_data_team2, 0, fn(m, acc) ->  if(Map.get(Map.get(m, "winner"), "id") == id_team2) do acc+1 else acc end end) / length(matches_data_team2)

  odds_team1 = 0.9 * (0.5 * (pct_win_team2 + (1 - pct_win_team2))) + :rand.uniform(10000)/100000
  odds_team2 = 1 - odds_team1

  [%{"name": Map.get(opponent1, "name"), "odds": odds_team1}, %{"name": Map.get(opponent2, "name"), "odds": odds_team2}]
end


# Part 3: Optimization
# Note that I did not implement a cache mechanism because of time constraints. I did look into it and thought about using ETS tables.
# I would first look up the data in the table (probably using match_id for the key), return it if it exists, else fetch the data, insert it in the table and then return it 
def odds_for_match_optimized(match_id) do

  match_info = match_data(match_id)
  opponent1 = Map.get(Enum.at(Map.get(match_info, "opponents"), 0), "opponent")
  opponent2 = Map.get(Enum.at(Map.get(match_info, "opponents"), 1), "opponent")
  serie_id = Map.get(match_info, "serie_id")

  id_team1 = Map.get(opponent1, "id")
  task1 = Task.async(fn -> get_matches_data_for_team_in_serie(serie_id, id_team1) end)
  id_team2 = Map.get(opponent2, "id")
  task2 = Task.async(fn -> get_matches_data_for_team_in_serie(serie_id, id_team2) end)

  matches_data_team1 = Task.await(task1);
  pct_win_team1 = Enum.reduce(matches_data_team1, 0, fn(m, acc) ->  if(Map.get(Map.get(m, "winner"), "id") == id_team1) do acc+1 else acc end end) / length(matches_data_team1)

  matches_data_team2 = Task.await(task2);
  pct_win_team2 = Enum.reduce(matches_data_team2, 0, fn(m, acc) ->  if(Map.get(Map.get(m, "winner"), "id") == id_team2) do acc+1 else acc end end) / length(matches_data_team2)

  odds_team1 = 0.9 * (0.5 * (pct_win_team2 + (1 - pct_win_team2))) + :rand.uniform(10000)/100000
  odds_team2 = 1 - odds_team1

  [%{"name": Map.get(opponent1, "name"), "odds": odds_team1}, %{"name": Map.get(opponent2, "name"), "odds": odds_team2}]
end

end


defmodule PandaTest do
  use ExUnit.Case
  doctest Panda

  test "upcoming_matches" do
    assert length(Panda.upcoming_matches()) == 5
  end

  test "team odds between 0 and 1" do
    matches = Panda.upcoming_matches()
    team_odds = Panda.odds_for_match(Map.get(Enum.at(matches, 0), "id"))
    team1_odds = Map.get(Enum.at(team_odds, 0), :odds)
    team2_odds = Map.get(Enum.at(team_odds, 1), :odds)
    assert team1_odds >= 0 and team1_odds <= 1
    assert team1_odds >= 0 and team1_odds <= 1
    assert team1_odds + team2_odds == 1
  end

end

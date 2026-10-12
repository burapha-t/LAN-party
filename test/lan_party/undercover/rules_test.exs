defmodule LanParty.Undercover.RulesTest do
  use ExUnit.Case, async: true

  alias LanParty.Undercover.Rules

  # Made-up pairs and a fixed shuffle, so no test depends on the contents of priv/undercover/pairs.txt.
  # The shuffle is used for the order of the pairs, for picking the undercovers, and for ordering a
  # pair's two words. With `identity`: pairs come in this order, the first k players are the
  # undercovers, and they get the pair's second word.
  @pairs [{"Alpha", "Beta"}, {"Cedar", "Dune"}, {"Ember", "Fjord"}, {"Gale", "Haze"}]
  @sorted_pairs Enum.map(@pairs, fn {a, b} -> Enum.sort([a, b]) end)

  defp identity(list), do: list
  defp tokens(n), do: Enum.map(1..n, &"p#{&1}")

  defp game(n \\ 3, opts \\ []),
    do: Rules.new(tokens(n), %{}, Keyword.merge([pairs: @pairs, shuffle: &identity/1], opts))

  defp reroll!(game) do
    assert {:ok, game} = Rules.table_action(game, :reroll)
    game
  end

  # `game` as deal 1, then deal 2 and so on up to deal `n`.
  defp deals(game, n),
    do: [game | Enum.scan(1..(n - 1)//1, game, fn _, game -> reroll!(game) end)]

  # The two words of a deal, sorted.
  defp pair_of(game), do: game.words |> Map.values() |> Enum.uniq() |> Enum.sort()

  # How many players hold the word that fewer players hold.
  defp minority(game),
    do: game.words |> Map.values() |> Enum.frequencies() |> Map.values() |> Enum.min()

  # {token, word} of the one player holding the odd word (3 to 5 players, so 1 undercover).
  defp odd_one(game) do
    frequencies = Enum.frequencies(Map.values(game.words))
    Enum.find(game.words, fn {_token, word} -> frequencies[word] == 1 end)
  end

  describe "new/3" do
    test "deals the first pair: everyone has a word, it is deal 1, and nobody has won" do
      game = game()

      assert game.players == ["p1", "p2", "p3"]
      assert game.deal == 1
      assert game.words |> Map.keys() |> Enum.sort() == ["p1", "p2", "p3"]
      assert Rules.winner(game) == nil
    end

    test "with a fixed shuffle: the first pair, the first player undercover with the second word" do
      assert game().words == %{"p1" => "Beta", "p2" => "Alpha", "p3" => "Alpha"}
    end

    test "a shuffle that reverses everything picks the last pair, the last player and the other word" do
      assert game(3, shuffle: &Enum.reverse/1).words == %{
               "p1" => "Haze",
               "p2" => "Haze",
               "p3" => "Gale"
             }
    end

    test "1 undercover with 3 to 5 players, 2 with 6 to 8" do
      for {players, undercovers} <- [{3, 1}, {4, 1}, {5, 1}, {6, 2}, {7, 2}, {8, 2}] do
        game = game(players)

        assert game.undercovers == undercovers
        assert minority(game) == undercovers
        assert length(pair_of(game)) == 2
      end
    end

    test "with the real shuffle: both words come from one pair, and exactly k players hold the other one" do
      for players <- [3, 5, 6, 8], _ <- 1..20 do
        game = game(players, shuffle: &Enum.shuffle/1)

        assert pair_of(game) in @sorted_pairs
        assert game.undercovers == if(players >= 6, do: 2, else: 1)
        assert minority(game) == game.undercovers
      end
    end

    test "which word goes to the undercovers is random, and so is who they are" do
      odd =
        for _ <- 1..100,
            do: odd_one(game(3, pairs: [{"Alpha", "Beta"}], shuffle: &Enum.shuffle/1))

      assert odd |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> Enum.sort() == ["Alpha", "Beta"]
      assert odd |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> Enum.sort() == ["p1", "p2", "p3"]
    end

    test "settings are ignored, and the defaults deal real words from the word list" do
      game = Rules.new(["a", "b", "c"], %{stack_plus2: true}, [])
      words = Rules.pairs() |> Enum.flat_map(&Tuple.to_list/1)

      assert game.deal == 1
      assert Enum.all?(Map.values(game.words), &(&1 in words))
      assert length(pair_of(game)) == 2
    end

    test "the game keeps indexes, not the word list: only a :pairs override is stored" do
      default = Rules.new(["a", "b", "c"], %{}, [])

      assert default.pairs == nil
      assert Enum.all?(default.deck, &is_integer/1)
      assert game().pairs == @pairs
    end
  end

  describe "rerolling" do
    test "deals the next pair and new roles to everyone, and counts the deal" do
      [first, second] = deals(game(), 2)

      assert first.deal == 1
      assert second.deal == 2
      assert pair_of(first) == ["Alpha", "Beta"]
      assert pair_of(second) == ["Cedar", "Dune"]
      assert second.words == %{"p1" => "Dune", "p2" => "Cedar", "p3" => "Cedar"}
    end

    test "every reroll draws the undercovers and their word again" do
      many = for i <- 1..60, do: {"a#{i}", "b#{i}"}

      odd =
        for game <- deals(game(3, pairs: many, shuffle: &Enum.shuffle/1), 50), do: odd_one(game)

      assert odd |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> length() > 1
      assert odd |> Enum.map(&String.first(elem(&1, 1))) |> Enum.uniq() |> length() == 2
    end

    test "no pair repeats within a game, until all of them have been dealt" do
      pairs = deals(game(3, shuffle: &Enum.shuffle/1), 4) |> Enum.map(&pair_of/1)

      assert Enum.sort(pairs) == Enum.sort(@sorted_pairs)
    end

    test "when the pairs run out they are shuffled again, and each is dealt once more" do
      pairs = deals(game(), 8) |> Enum.map(&pair_of/1)

      assert pairs == @sorted_pairs ++ @sorted_pairs
    end

    test "the pair just dealt doesn't come straight back after a reshuffle" do
      two = [{"Alpha", "Beta"}, {"Cedar", "Dune"}]
      sets = deals(game(3, pairs: two, shuffle: &Enum.shuffle/1), 41) |> Enum.map(&pair_of/1)

      assert Enum.zip(sets, tl(sets)) |> Enum.all?(fn {a, b} -> a != b end)
    end

    test "the undercover count follows the players left at the reroll" do
      six = game(6)
      assert six.undercovers == 2

      assert six |> Rules.remove_player("p6") |> reroll!() |> Map.get(:undercovers) == 1

      eight = game(8) |> Rules.remove_player("p8")
      assert reroll!(eight).undercovers == 2

      two =
        six
        |> Rules.remove_player("p6")
        |> Rules.remove_player("p5")
        |> Rules.remove_player("p4")
        |> Rules.remove_player("p3")

      two = reroll!(two)
      assert two.players == ["p1", "p2"]
      assert two.undercovers == 1
      assert minority(two) == 1
    end
  end

  describe "remove_player/2" do
    test "a kicked player's word leaves the game" do
      game = Rules.remove_player(game(), "p2")

      assert game.players == ["p1", "p3"]
      assert game.words == %{"p1" => "Beta", "p3" => "Alpha"}
      assert Rules.winner(game) == nil
    end

    test "the dealt undercover count stays as it was, even when the kicked player was an undercover" do
      six = game(6)
      # p1 and p2 are the undercovers under the fixed shuffle.
      kicked = Rules.remove_player(six, "p1")

      assert kicked.undercovers == 2
      assert kicked.deal == 1
      assert kicked.words == Map.delete(six.words, "p1")
    end

    test "the Room's last-player-left rule ends the game, not the rules" do
      game = game() |> Rules.remove_player("p1") |> Rules.remove_player("p2")

      assert game.players == ["p3"]
      assert Rules.winner(game) == nil
    end
  end

  test "phones have no moves" do
    assert Rules.apply_action(game(), "p1", :reroll) == {:error, :no_actions}
  end

  test "a table action Undercover doesn't know is refused" do
    assert Rules.table_action(game(), :roll) == {:error, :unknown_action}
    assert Rules.table_action(game(), {:count, 4}) == {:error, :unknown_action}
  end

  describe "the word list (priv/undercover/pairs.txt)" do
    test "every pair has two different non-empty words, and no pair appears twice" do
      pairs = Rules.pairs()

      for {a, b} <- pairs do
        assert String.trim(a) != "" and String.trim(b) != ""
        assert String.downcase(a) != String.downcase(b), "#{a} | #{b} is the same word twice"
      end

      keys = Enum.map(pairs, fn {a, b} -> Enum.sort([String.downcase(a), String.downcase(b)]) end)
      assert keys -- Enum.uniq(keys) == [], "pairs listed twice"
    end
  end
end

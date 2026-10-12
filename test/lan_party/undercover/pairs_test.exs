defmodule LanParty.Undercover.PairsTest do
  use ExUnit.Case, async: true

  alias LanParty.Undercover.Pairs

  test "one pair per line, split on the bar, both sides trimmed" do
    assert Pairs.parse!("Coffee | Tea\n  Cat|Tiger  \nBeach  |  Swimming pool\n") ==
             [{"Coffee", "Tea"}, {"Cat", "Tiger"}, {"Beach", "Swimming pool"}]
  end

  test "blank lines and lines starting with # are skipped" do
    text = """
    # Undercover word pairs

    # General
    Coffee | Tea
       # an indented comment
    \t
    Cat | Tiger
    """

    assert Pairs.parse!(text) == [{"Coffee", "Tea"}, {"Cat", "Tiger"}]
  end

  test "Windows line endings and a byte order mark are fine" do
    assert Pairs.parse!("﻿# General\r\nCoffee | Tea\r\nCat | Tiger\r\n") ==
             [{"Coffee", "Tea"}, {"Cat", "Tiger"}]
  end

  test "a line that isn't exactly two non-empty words raises, naming the file and the line" do
    for bad <- ["Coffee", "Coffee |", "| Tea", " | ", "Coffee | Tea | Milk", "Coffee Tea"] do
      error =
        assert_raise ArgumentError, fn ->
          Pairs.parse!("# General\nCat | Tiger\n#{bad}\n", "pairs.txt")
        end

      assert error.message =~ "pairs.txt, line 3"
      assert error.message =~ inspect(String.trim(bad))
    end
  end

  test "a list with no pairs raises" do
    assert_raise ArgumentError, ~r/no word pairs/, fn -> Pairs.parse!("# only a comment\n\n") end
  end
end

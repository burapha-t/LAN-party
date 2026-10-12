defmodule LanPartyWeb.Undercover.ComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import LanPartyWeb.Undercover.Components

  defp slip_html(word) do
    assigns = %{word: word}

    rendered_to_string(~H"""
    <.slip word={@word} />
    """)
  end

  test "a slip shows its word" do
    html = slip_html("Coffee")

    assert html =~ ~r/class="slip\s*"/
    refute html =~ "dealt"
    assert html =~ ~r/<span class="slip-word [^"]+">Coffee<\/span>/
  end

  test "the word's size steps down with its length" do
    sizes = [
      {"Cat", "size-xl"},
      {"Moon", "size-xl"},
      {"Coffee", "size-l"},
      {"Pizza!", "size-l"},
      {"Hot dog", "size-m"},
      {"Ice cream", "size-m"},
      {"Ice cream!", "size-m"},
      {"Swimming pool", "size-s"},
      {"Table tennis!", "size-s"},
      {"Chocolate pudding", "size-xs"},
      {"Sixteen letters!", "size-xs"}
    ]

    for {word, size} <- sizes do
      assert slip_html(word) =~ ~s(class="slip-word #{size}"), "#{word} should be #{size}"
    end
  end

  test "a slip dealt in plays the animation; the id and extra attributes pass through" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.slip id="slip-3" word="Tea" dealt style="--r:4deg" />
      """)

    assert html =~ ~s(id="slip-3")
    assert html =~ ~s(class="slip dealt")
    assert html =~ ~s(style="--r:4deg")
  end
end

defmodule LanPartyWeb.LiarsDice.ComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import LanPartyWeb.LiarsDice.Components

  defp pips(html), do: length(String.split(html, "<i></i>")) - 1

  test "a flat face has one pip per point" do
    for value <- 1..6 do
      assigns = %{value: value}

      html =
        rendered_to_string(~H"""
        <.face value={@value} />
        """)

      assert html =~ ~s(class="pips n#{value}")
      assert pips(html) == value
    end
  end

  test "a face passes extra attributes through" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.face value={5} style="--x:62%" />
      """)

    assert html =~ ~s(style="--x:62%")
  end

  test "a 3D die has all six sides and is labelled with its value" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.die id="die-1-0" value={3} />
      """)

    assert html =~ ~s(id="die-1-0")
    assert html =~ ~s(class="die v3")
    assert html =~ ~s(role="img")
    assert html =~ ~s(aria-label="3")
    assert html =~ ~s(class="cube" aria-hidden="true")
    for side <- 1..6, do: assert(html =~ ~s(class="pips n#{side} s#{side}"))
    assert pips(html) == 21
  end

  test "rolling plays the animation; a count lights a die up or dims it" do
    assigns = %{}

    assert rendered_to_string(~H"""
           <.die value={4} rolling />
           """) =~ ~s(class="die v4 rolling")

    assert rendered_to_string(~H"""
           <.die value={4} state="lit" />
           """) =~ ~s(class="die v4 lit")

    assert rendered_to_string(~H"""
           <.die value={2} rolling state="dim" />
           """) =~ ~s(class="die v2 rolling dim")
  end
end

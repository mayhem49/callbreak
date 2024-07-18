defmodule CallbreakWeb.ErrorJSONTest do
  use CallbreakWeb.ConnCase, async: true

  test "renders 404" do
    assert CallbreakWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert CallbreakWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end

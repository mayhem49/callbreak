defmodule CallbreakWeb.TestLive do
  use CallbreakWeb, :live_view

  def mount(_, _, socket) do
    {:ok, socket}
  end

  def js do
    JS.add_class("highlight underline",
      to: "#item",
      transition: {"ease-out duration-10000", "opacity-0", "opacity-100"},
      time: 20 * 1000
    )
  end

  def render(assigns) do
    ~H"""
    <div id="item">My Item</div>
    <button phx-click={js()}>
      highlight!
    </button>
    """
  end
end

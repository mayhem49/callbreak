defmodule CallbreakWeb.Test do
  use CallbreakWeb, :live_view
  require Logger

  def mount(params, session, socket) do
  end

  def render(assigns) do
    ~H"""
    <div>
      This is a livevie component.
    </div>
    """
  end
end

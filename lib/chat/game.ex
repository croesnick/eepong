# TODO Should use Phoenix.Channel.
# This way we guarantee that every game handles its own events and nothing else.
defmodule Chat.Game do
  use GenServer
  require Logger

  def start(game_id) do
    GenServer.start(
      __MODULE__,
      %{game: game_id, channel: "game:#{game_id}"},
      name: via_tuple(game_id)
    )
  end

  def send_event(game, event) do
    GenServer.cast via_tuple(game), {:send, %{event: event}}
  end

  def handle_event(game, event) do
    pid = whereis game
    Logger.debug "Got game event: #{inspect game}"
  end

  def handle_cast({:send, event}, state) do
    Chat.Endpoint.broadcast! state.channel, "event", event
  end

  def whereis(game) do
    :gproc.whereis_name({:n, :l, {:game, game}})
  end

  defp via_tuple(game) do
    {:via, :gproc, {:n, :l, {:game, game}}}
  end
end
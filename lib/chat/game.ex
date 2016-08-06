# TODO Should use Phoenix.Channel.
# This way we guarantee that every game handles its own events and nothing else.
defmodule Chat.Game do
  use GenServer
  require Logger

  def start(game_id, player1, player2) do
    GenServer.start(
      __MODULE__,
      %{ game:    game_id,
         channel: "game:#{game_id}",
         users:   [player1, player2] },
      name: via_tuple(game_id)
    )
  end

  def opponent(game_id, player) do
    GenServer.call via_tuple(game_id), {:get_opponent, player}
  end

#  def send_event(game, event) do
#    GenServer.cast via_tuple(game), {:send, %{event: event}}
#  end

#  def handle_event(game, event) do
#    pid = whereis game
#    Logger.debug "Got game event: #{inspect game}"
#  end

  def handle_call({:get_opponent, player}, _from, state) do
    [player1, player2] = state.users
    opponent = if (player.assigns.user_id == player1.assigns.user_id) do
                 player2
               else
                 player1
               end

    {:reply, opponent, state}
  end

#  def handle_cast({:send, event}, state) do
#    Chat.Endpoint.broadcast! state.channel, "event", event
#  end

  def whereis(game) do
    :gproc.whereis_name({:n, :l, {:game, game}})
  end

  defp via_tuple(game) do
    {:via, :gproc, {:n, :l, {:game, game}}}
  end
end

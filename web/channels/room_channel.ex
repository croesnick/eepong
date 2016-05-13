defmodule Chat.RoomChannel do
  use Phoenix.Channel
  require Logger

  @doc """
  Authorize socket to subscribe and broadcast events on this channel & topic

  Possible Return Values

  `{:ok, socket}` to authorize subscription for channel for requested topic

  `:ignore` to deny subscription/broadcast on this channel
  for the requested topic
  """
  def join("rooms:lobby", message, socket) do
    Process.flag(:trap_exit, true)
    :timer.send_interval(10000, :ping)
    send(self, {:after_join, message})

    {:ok, socket}
  end

  def join("rooms:" <> _private_subtopic, _message, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  def join("game:" <> game_id, _message, socket) do
    send(self, {:game_after_join, %{game: game_id}})
    {:ok, socket}
  end

  def handle_info({:after_join, msg}, socket) do
    login_user socket.assigns.user_id, socket

    broadcast! socket, "user:entered", %{user: msg["user"]}
    push socket, "join", %{status: "connected"}
    {:noreply, socket}
  end

  def handle_info({:game_after_join, %{game: game_id}}, socket) do
    Logger.info "User #{socket.assigns.user_id} joined game #{inspect game_id}"
    assign socket, :game, game_id

    # -- The js-part subscribed to the channel
    # Logger.info "Subscribing user #{socket.assigns.user_id} to game channel"
    # Chat.Endpoint.subscribe self(), "game:#{game_id}"

    {:noreply, socket}
  end

  def handle_info(:ping, socket) do
    push socket, "new:msg", %{user: "SYSTEM", body: "ping"}
    {:noreply, socket}
  end

  def terminate(reason, socket) do
    Logger.debug"> leave #{inspect reason}"

    logout_user socket.assigns.user_id
    :ok
  end

  def handle_in("new:msg", msg, socket) do
    broadcast! socket, "new:msg", %{user: msg["user"], body: msg["body"]}
    {:reply, {:ok, %{msg: msg["body"]}}, assign(socket, :user, msg["user"])}
  end

  def handle_in("game:new", _msg, socket) do
    # send a message to the first player in the list which is not myself
    {other_player, other_socket} = Chat.Users.waiting
                                   |> Enum.find( fn({some_user, _some_socket}) ->
                                        some_user != socket.assigns.user_id
                                      end)

    case other_player do
      nil ->
        Logger.warn "There is only one player connected..."
      _ ->
        game_id = UUID.uuid1

        Logger.info "Creating new game #{game_id}"
        Chat.Game.start game_id

        Logger.info "Sending join-message to both users"
        :ok = push socket, "game:join", %{game: game_id}
        :ok = push other_socket, "game:join", %{game: game_id}
    end
    {:noreply, socket}
  end

  # TODO Should be moved into Chat.Game.
  def handle_in("event", %{"event" => event}, socket) do
    # TODO add guard for possible event names
    Chat.Game.handle_event socket.assigns.game, String.to_atom(event)
    {:noreply, socket}
  end

  defp login_user(user, socket) do
    :ok = Chat.Users.add user, socket
  end

  defp logout_user(user) do
    Chat.Users.remove user
  end
end

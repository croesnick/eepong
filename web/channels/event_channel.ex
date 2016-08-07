defmodule EEPong.EventChannel do
  use Phoenix.Channel
  require Logger

  def join("rooms:lobby", message, socket) do
    Logger.info "Got message when logging in: #{inspect message}"

    # Trapping exists means we get notified whenever a user disconnects
    # (intentially or by crash, timeoout, or whatever reason).
    Process.flag(:trap_exit, true)
    send(self, {:after_room_join, message})

    {:ok, socket}
  end

  def join("rooms:" <> _private_subtopic, _message, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  def handle_info({:after_room_join, _message}, socket) do
    user_id = socket.assigns.user_id

    login_user user_id, socket
    broadcast! socket, "server_event:user:join", %{user_name: user_id}
    {:noreply, assign(socket, :user_name, user_id)}
  end

  def join("game:" <> game_id, _message, socket) do
    send(self, {:game_after_join, %{game: game_id}})
    {:ok, socket}
  end

  def handle_in("client_event:game:new", _msg, socket) do
    # send a message to the first player in the list which is not myself
    {other_player, other_socket} =
        EEPong.Users.waiting
        |> Enum.find( fn({some_user, _some_socket}) ->
             some_user != socket.assigns.user_id
           end)

    case other_player do
      nil ->
        #TODO Send in-game message to player +socket+
        #:ok = push socket "msg:new", "..."
        Logger.warn "There is only one player connected..."
      _ ->
        game_id = UUID.uuid1

        Logger.info "Creating new game #{game_id}"
        EEPong.Game.start game_id, socket, other_socket

        Logger.info "Sending join-message to both users"
        :ok = push socket, "server_event:game:join", %{game: game_id}
        :ok = push other_socket, "server_event:game:join", %{game: game_id}
    end
    {:noreply, socket}
  end

  def handle_info({:game_after_join, %{game: game_id}}, socket) do
#    Logger.info "User #{socket.assigns.user_name} joined game #{inspect game_id}"
    {:noreply, assign(socket, :game_id, game_id)}
  end

  def handle_in("client_event:user:data", message, socket) do
    broadcast! socket,
               "server_event:user:nameChange",
               %{name_now:    message["user_name"],
                 name_before: socket.assigns.user_name}

    {:noreply, assign(socket, :user_name, message["user_name"])}
  end

  # There are several event types:
  # - Simple move updates (space, paddle)
  #   -> game:event, {"name" => "move", "data" => {...}}
  # - One player scored a point
  #   -> game:event {"name" => "score", "data" => {...}}
  # - Game ended
  #   -> game:event {"name" => "end_game", "data" => {...}}

  def handle_in("client_event:game:state", %{"space" => space, "paddle" => paddle} = event, socket) do
    if Map.has_key?(socket.assigns, :game_id) do
      game_id = socket.assigns.game_id
      opponent_socket = EEPong.Game.opponent game_id, socket

      user_id = socket.assigns.user_id
      opponent_user_id = opponent_socket.assigns.user_id

      if user_id != opponent_socket do
        :ok = push opponent_socket, "server_event:game:state", event
      end
    end

    {:noreply, socket}
  end

  def terminate(reason, socket) do
    Logger.debug"> leave #{inspect reason}"

    logout_user socket.assigns.user_id
    :ok
  end

  defp change_user_name(name, socket) do
    :ok = EEPong.Users.name name, socket
  end

  defp login_user(user, socket) do
    :ok = EEPong.Users.add user, socket
  end

  defp logout_user(user) do
    EEPong.Users.remove user
  end
end

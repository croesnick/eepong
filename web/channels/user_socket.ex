defmodule EEPong.UserSocket do
  use Phoenix.Socket
  require Logger

  channel "rooms:*", EEPong.RoomChannel
  channel "game:*",  EEPong.RoomChannel

  transport :websocket, Phoenix.Transports.WebSocket
  transport :longpoll, Phoenix.Transports.LongPoll

  def connect(params, socket) do
    # Naiver Gedanke: Hier muss ich mir den Socket für den Nutzer merken,
    # um dann auf dem Channel send an alle anderen Spieler des jeweiligen
    # Spiels senden zu können.

    # {:ok, socket}
    {:ok, assign(socket, :user_id, params["user_id"])}
  end

  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end

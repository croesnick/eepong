# This is what should later become the PlayerRegistry :)
defmodule Chat.Users do
  use GenServer
  require Logger

  @name __MODULE__

  def start_link do
    GenServer.start_link(
      __MODULE__,
      %{},
      name: @name #, debug: [:trace]
    )
  end

  def add(user, socket) do
    GenServer.call @name, {:add, user, socket}
  end

  def remove(user) do
    GenServer.call @name, {:remove, user}
  end

  def waiting do
    GenServer.call @name, :waiting
  end

  # internal api

  def handle_call({:add, user, socket}, _from, state) do
    case Map.has_key?(state, user) do
      true ->
        {:reply, :already_registered, state}
      false ->
        {:reply, :ok, Map.put(state, user, socket)}
    end
  end

  def handle_call({:remove, user}, _from, state) do
    case Map.has_key?(state, user) do
      true ->
        {:reply, :ok, Map.delete(state, user)}
      false ->
        {:reply, :not_registered, state}
    end
  end

  def handle_call(:waiting, _from, state) do
    Logger.debug "Waiting users: #{inspect Enum.map(state, fn({id, _}) -> id end)}"
    {:reply, state, state}
  end
end

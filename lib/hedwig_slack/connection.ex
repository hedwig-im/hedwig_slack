defmodule HedwigSlack.Connection do
  @behaviour :websocket_client

  alias HedwigSlack.{Connection, ConnectionSupervisor}

  require Logger

  @keepalive 30_000

  defstruct next_id: 1, owner: nil, ref: nil

  ### PUBLIC API ###

  def start(url) do
    {:ok, pid} = Supervisor.start_child(ConnectionSupervisor, [url, self()])
    ref = Process.monitor(pid)
    {:ok, pid, ref}
  end

  def start_link(url, owner) do
    :websocket_client.start_link(to_charlist(url), __MODULE__, owner)
  end

  def ws_send(pid, msg) do
    send(pid, {:ws_send, msg})
    :ok
  end

  def close(pid, timeout \\ 5000) do
    send(pid, :close)
    receive do
      {:DOWN, _, :process, ^pid, _reason} ->
        :ok
    after timeout ->
      true = Process.exit(pid, :kill)
      :ok
    end
  end

  ### :websocket_client callbacks ###

  def init(owner) do
    ref = Process.monitor(owner)
    {:reconnect, %Connection{owner: owner, ref: ref}}
  end

  def onconnect(_req, state) do
    {:ok, state, @keepalive}
  end

  def ondisconnect(reason, state) do
    Logger.warn "Disconnected: #{inspect reason}"
    {:close, reason, state}
  end

  def websocket_handle({:text, data}, _ref, state) do
    send(self(), {:handle_data, data})
    {:ok, state}
  end

  def websocket_handle({:ping, data}, _req, state) do
    {:reply, {:pong, data}, state}
  end

  def websocket_handle({:pong, _data}, _req, state) do
    {:ok, state}
  end

  def websocket_handle(msg, _req, state) do
    Logger.warn "Received unhandled websocket message: #{inspect msg}"
    {:ok, state}
  end

  def websocket_info(:close, _req, state) do
    {:close, <<>>, state}
  end

  def websocket_info({:DOWN, ref, :process, pid, _reason}, _req, %{owner: pid, ref: ref} = state) do
    {:close, <<>>, state}
  end

  def websocket_info({:handle_data, data}, _req, %{owner: owner} = state) do
    data = Jason.decode!(data)
    Logger.debug "INCOMING > #{inspect data}"
    send(owner, data)

    {:ok, state}
  end

  def websocket_info({:ws_send, msg}, _from, %{next_id: id} = state) do
    msg = Map.put(msg, :id, id)
    Logger.debug "OUTGOING > #{inspect msg}"
    msg = Jason.encode!(msg)

    {:reply, {:text, msg}, %{state | next_id: id + 1}}
  end

  def websocket_info(msg, _req, state) do
    Logger.warn "Received unhandled message: #{inspect msg}"
    {:ok, state}
  end

  def websocket_terminate(_reason, _req, _state) do
    :ok
  end
end

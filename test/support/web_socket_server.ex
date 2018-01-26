defmodule HedwigSlack.WebSocketServer do
  @behaviour :cowboy_websocket_handler
  @listen_ip {127, 0, 0, 1}

  def open(handler) do
    ref = make_ref()
    port = get_available_port()
    start_socket(handler, port, ref)
  end

  defp get_available_port do
    {:ok, socket} = :ranch_tcp.listen(ip: @listen_ip, port: 0)
    {:ok, port} = :inet.port(socket)
    true = :erlang.port_close(socket)

    port
  end

  defp start_socket(handler, port, ref) do
    {:ok, socket} = :ranch_tcp.listen(ip: @listen_ip, port: port)
    dispatch = [{:_, [{:_, handler, []}]}]
    cowboy_opts = [ref: ref, acceptors: 3, port: port, socket: socket, dispatch: dispatch]
    {:ok, pid} = Plug.Adapters.Cowboy.http(__MODULE__, [], cowboy_opts)

    %{pid: pid, port: port}
  end

  ## WebSocket Callbacks

  require Logger

  def init(_, req, opts) do
    {:upgrade, :protocol, :cowboy_websocket, req, opts}
  end

  def websocket_init(_, req, opts) do
    send(self(), :init)
    {:ok, req, opts, 5000}
  end

  def websocket_handle({:ping, msg}, req, state) do
    {:reply, {:pong, msg}, req, state}
  end

  def websocket_handle({:text, msg}, req, state) do
    %{"id" => id} = Jason.decode!(msg)
    {:reply, {:text, ~s({"ok":true,"reply_to":#{id}})}, req, state}
  end

  def websocket_info(:init, req, state) do
    {:reply, {:text, ~s({"type":"hello"})}, req, state}
  end

  def websocket_terminate(_reason, _req, _state) do
    :ok
  end
end

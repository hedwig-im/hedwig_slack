defmodule Hedwig.Adapters.Slack.Connection do
  use GenServer

  require Logger

  @endpoint "https://slack.com/api/rtm.start"

  defmodule State do
    defstruct conn: nil,
              host: nil,
              next_id: 1,
              owner: nil,
              path: nil,
              port: nil,
              ref: nil,
              token: nil,
              query: %{},
              server_data: %{},
              reconnect_url: nil
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, {self, opts})
  end

  def ws_send(pid, msg) do
    GenServer.call(pid, {:ws_send, msg})
  end

  def init({owner, opts}) do
    %URI{host: host, port: port, path: path, query: query} =
      URI.parse(opts[:endpoint] || @endpoint)

    {:ok, conn} = :gun.open(to_char_list(host), port)

    :ok = GenServer.cast(self(), :rtm_start)

    {:ok, %State{
       conn: conn,
       host: host,
       owner: owner,
       port: port,
       path: path,
       token: opts[:token],
       query: query}}
  end

  def handle_call({:ws_send, msg}, _from, %{conn: conn, next_id: id} = state) do
    msg = msg |> Map.put(:id, id) |> Poison.encode!()
    :ok = :gun.ws_send(conn, {:text, msg})
    {:reply, :ok, %{state | next_id: id + 1}}
  end

  def handle_cast(:rtm_start, %{conn: conn} = state) do
    ref = :gun.get(conn, rtm_path(state))
    {:ok, body} = :gun.await_body(conn, ref)
    decoded = Poison.decode!(body)

    for user <- decoded["users"] do
      send(state.owner, {:user, user})
    end

    :ok = GenServer.cast(self(), :ws_upgrade)
    {:noreply, %{state | ref: ref, server_data: decoded}}
  end

  def handle_cast(:ws_upgrade, %{conn: conn, server_data: %{"url" => url}} = state) do
    %URI{host: host, path: path} = URI.parse(url)
    :ok = :gun.close(conn)
    {:ok, conn} = :gun.open(to_char_list(host), 443)
    ref = :gun.ws_upgrade(conn, to_char_list(path))
    {:noreply, %{state | conn: conn, ref: ref}}
  end

  def handle_info({:gun_response, _conn, _ref, _is_fin, _status, headers}, state) do
    {:noreply, state}
  end

  def handle_info({:gun_ws_upgrade, _conn, :ok, _headers}, state) do
    {:noreply, state}
  end

  def handle_info({:gun_ws, conn, {:text, data}}, %{conn: conn} = state) do
    send(self(), {:handle_data, Poison.decode!(data)})
    {:noreply, state}
  end

  def handle_info({:handle_data, %{"type" => "reconnect_url", "url" => url} = msg}, state) do
    {:noreply, %{state | reconnect_url: url}}
  end

  def handle_info({:handle_data, data}, state) do
    handle_data(data, state.owner)
    {:noreply, state}
  end

  def handle_info({:gun_down, _conn, :http, _reason, _, _} = msg, state) do
    IO.inspect msg
    {:noreply, state}
  end

  def handle_info({:gun_down, _conn, :ws, _reason, _, _} = msg, state) do
    IO.inspect msg
    {:noreply, state}
  end

  def handle_info({:gun_up, _conn, :http}, state) do
    {:noreply, state}
  end

  def handle_info(msg, state) do
    IO.inspect msg
    {:noreply, state}
  end

  defp handle_data(%{"type" => "hello"}, _owner) do
    Logger.info "Connected Successfully!"
  end

  defp handle_data(data, owner) do
    send(owner, data)
  end

  defp rtm_path(%{path: path, query: nil, token: token}), do:
    '#{path}?token=#{token}'
  defp rtm_path(%{path: path, query: query, token: token}), do:
    '#{path}?#{URI.encode_query(Map.put(query, token: token))}'
end

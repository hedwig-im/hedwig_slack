defmodule Hedwig.Adapters.Slack.Connection do
  use Connection

  require Logger

  @timeout 5_000
  @endpoint "https://slack.com/api/rtm.start"

  defstruct conn: nil,
            host: nil,
            last_pong_ts: nil,
            next_id: 1,
            owner: nil,
            path: nil,
            port: nil,
            ref: nil,
            timer: nil,
            token: nil,
            query: %{}

  ### PUBLIC API ###

  def start_link(opts) do
    %URI{host: host, port: port, path: path, query: query} =
      URI.parse(opts[:endpoint] || @endpoint)

    opts =
      opts
      |> Keyword.put(:host, host)
      |> Keyword.put(:port, port)
      |> Keyword.put(:path, path)
      |> Keyword.put(:query, query)
      |> Keyword.put(:owner, self())

    Connection.start_link(__MODULE__, struct(__MODULE__, opts))
  end

  def ws_send(pid, msg) do
    Connection.call(pid, {:ws_send, msg})
  end

  def close(pid) do
    Connection.call(pid, :close)
  end

  ### Connection callbacks ###

  def init(state) do
    {:connect, :init, state}
  end

  def connect(info, %{host: host, port: port} = state) when info in [:init, :backoff] do
    case :gun.open(to_char_list(host), port) do
      {:ok, conn} ->
        receive do
          {:gun_up, ^conn, :http} ->
            connect(:rtm_start, %{state | conn: conn})
        after @timeout ->
          Logger.error "Unable to connect"
          {:backoff, @timeout, state}
        end
      {:error, _} ->
        {:backoff, @timeout, state}
    end
  end

  def connect(:rtm_start, %{conn: conn, owner: owner} = state) do
    Logger.info "RTM Start"
    ref = :gun.get(conn, rtm_path(state))

    case :gun.await_body(conn, ref) do
      {:ok, body} ->
        decoded = Poison.decode!(body)

        send(owner, {:channels, decoded["channels"]})
        send(owner, {:groups, decoded["groups"]})
        send(owner, {:self, decoded["self"]})
        send(owner, {:users, decoded["users"]})

        :ok = :gun.close(conn)

        connect({:ws_upgrade, decoded["url"]}, %{state | conn: nil})
      {:error, _} ->
        {:backoff, @timeout, state}
    end
  end

  def connect({:ws_upgrade, url}, state) do
    # TODO: Move these into application startup?
    URI.default_port("ws", 80)
    URI.default_port("wss", 443)

    %URI{host: host, path: path, port: port} = URI.parse(url)

    case :gun.open(to_char_list(host), port) do
      {:ok, conn} ->
        ref = :gun.ws_upgrade(conn, to_char_list(path))
        receive do
          {:gun_ws_upgrade, ^conn, :ok, _headers} ->
            {:ok, timer} = :timer.send_interval(30_000, :send_ping)
            {:ok, %{state | conn: conn, ref: ref, timer: timer}}
        after @timeout ->
          {:backoff, @timeout, state}
        end
      {:error, _} ->
        {:backoff, @timeout, state}
    end
  end

  def disconnect({:close, from}, %{conn: conn, timer: timer} = state) do
    :ok = :gun.close(conn)
    {:ok, :cancel} = :timer.cancel(timer)
    Connection.reply(from, :ok)

    {:stop, :normal, %{state | conn: nil,
                               last_pong_ts: nil,
                               ref: nil,
                               timer: nil}}
  end

  def disconnect(:reconnect, %{conn: conn, timer: timer} = state) do
    :ok = :gun.close(conn)
    {:ok, :cancel} = :timer.cancel(timer)

    {:connect, :init, %{state | conn: nil,
                                last_pong_ts: nil,
                                ref: nil,
                                timer: nil}}
  end

  def handle_call({:ws_send, msg}, _from, %{conn: conn, next_id: id} = state) do
    msg = msg |> Map.put(:id, id) |> Poison.encode!()
    :ok = :gun.ws_send(conn, {:text, msg})

    {:reply, :ok, %{state | next_id: id + 1}}
  end

  def handle_call(:close, from, state) do
    {:disconnect, {:close, from}, state}
  end

  def handle_info({:gun_response, _, _, _, _, _}, state), do: {:noreply, state}

  def handle_info({:gun_ws, conn, {:text, data}}, %{conn: conn} = state) do
    send(self(), {:handle_data, Poison.decode!(data)})
    {:noreply, state}
  end

  def handle_info({:handle_data, data}, state) do
    handle_data(data, state.owner)
    {:noreply, state}
  end

  def handle_info({:gun_down, _conn, :http, _reason, _, _} = msg, state) do
    msg |> inspect |> Logger.info
    {:disconnect, :reconnect, state}
  end

  def handle_info({:gun_down, _conn, :ws, _reason, _, _} = msg, state) do
    msg |> inspect |> Logger.info
    {:disconnect, :reconnect, state}
  end

  def handle_info({:gun_up, conn, :http}, state) do
    {:noreply, %{state | conn: conn}}
  end

  def handle_info(:send_ping, %{conn: conn, last_pong_ts: ts, next_id: id} = state) do
    now = unix_now

    if now - (ts || now) > 60 do
      Logger.error "Have not received 'pong' within 60 secs. Attempting to reconnect."
      {:disconnect, :reconnect, state}
    else
      Logger.info "Sending ping"
      msg = Poison.encode!(%{id: id, type: "ping"})
      :ok = :gun.ws_send(conn, {:text, msg})

      {:noreply, %{state | next_id: id + 1}}
    end
  end

  def handle_info(:pong, state) do
    {:noreply, %{state | last_pong_ts: unix_now}}
  end

  defp handle_data(%{"type" => "pong"}, _owner) do
    send(self(), :pong)
  end

  defp handle_data(%{"type" => "hello"}, owner) do
    send(owner, :connection_ready)
    Logger.info "Connected Successfully!"
  end

  defp handle_data(data, owner) do
    send(owner, data)
  end

  defp rtm_path(%{path: path, query: nil, token: token}), do:
    '#{path}?token=#{token}'
  defp rtm_path(%{path: path, query: query, token: token}), do:
    '#{path}?#{query |> Map.put(:token, token) |> URI.encode_query}'

  defp unix_now, do: :os.system_time(:seconds)
end

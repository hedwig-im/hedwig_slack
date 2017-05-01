defmodule Hedwig.Adapters.Slack do
  use Hedwig.Adapter

  require Logger

  alias HedwigSlack.{Connection, RTM, User}

  defmodule State do
    defstruct conn: nil,
              conn_ref: nil,
              channels: %{},
              groups: %{},
              id: nil,
              name: nil,
              opts: nil,
              robot: nil,
              token: nil,
              users: %{}
  end

  def init({robot, opts}) do
    {token, opts} = Keyword.pop(opts, :token)
    GenServer.cast(self(), :fetch_user_list)
    {:ok, %State{opts: opts, robot: robot, token: token}}
  end

  def handle_cast({:send, msg}, %{conn: conn} = state) do
    Connection.ws_send(conn, slack_message(msg))
    {:noreply, state}
  end

  def handle_cast({:reply, %{user: user, text: text} = msg}, %{conn: conn, users: _users} = state) do
    msg = %{msg | text: "<@#{user.id}|#{user.name}>: #{text}"}
    Connection.ws_send(conn, slack_message(msg))
    {:noreply, state}
  end

  def handle_cast({:emote, %{text: _text} = msg}, %{conn: conn} = state) do
    Connection.ws_send(conn, slack_message(msg, %{subtype: "me_message"}))
    {:noreply, state}
  end

  def handle_cast({:users, users}, %{users: {pid, ref}} = state) do
    true = Process.demonitor(ref)
    GenServer.stop(pid)
    GenServer.cast(self(), :rtm_connect)
    {:noreply, %{state | users: reduce(users["members"], %{})}}
  end

  def handle_cast(:fetch_user_list, %{opts: opts, token: token} = state) do
    http_opts = Keyword.get(opts, :recv_timeout, @default_recv_timeout)
    {:ok, pid, ref} = User.list(token, http_opts)

    {:noreply, %{state | users: {pid, ref}}}
  end

  def handle_cast(:rtm_connect, %{token: token} = state) do
    case RTM.connect(token) do
      {:ok, %{body: data}} ->
        Kernel.send(self(), {:self, data["self"]})
        {:ok, conn, ref} = Connection.start(data["url"])
        {:noreply, %State{state | conn: conn, conn_ref: ref}}
      {:error, _} = error ->
        handle_network_failure(error, state)
    end
  end

  # Ignore all messages from the bot.
  def handle_info(%{"user" => user}, %{id: user} = state) do
    {:noreply, state}
  end

  #def handle_info(%{"subtype" => "channel_join", "channel" => channel, "user" => user}, state) do
    #channels = put_channel_user(state.channels, channel, user)
    #{:noreply, %{state | channels: channels}}
  #end

  #def handle_info(%{"subtype" => "channel_leave", "channel" => channel, "user" => user}, state) do
    #channels = delete_channel_user(state.channels, channel, user)
    #{:noreply, %{state | channels: channels}}
  #end

  def handle_info(%{"type" => "message", "user" => user} = msg, %{robot: robot, users: users} = state) do
    msg = %Hedwig.Message{
      ref: make_ref(),
      robot: robot,
      room: msg["channel"],
      text: msg["text"],
      type: "message",
      user: %Hedwig.User{
        id: user,
        name: users[user]["name"]
      }
    }

    if msg.text do
      :ok = Hedwig.Robot.handle_in(robot, msg)
    end

    {:noreply, state}
  end

  #def handle_info({:channels, channels}, state) do
    #{:noreply, %{state | channels: reduce(channels, state.channels)}}
  #end

  #def handle_info({:groups, groups}, state) do
    #{:noreply, %{state | groups: reduce(groups, state.groups)}}
  #end

  def handle_info({:self, %{"id" => id, "name" => name}}, state) do
    {:noreply, %{state | id: id, name: name}}
  end

  def handle_info(%{"type" => "team_join", "user" => user}, state) do
    {:noreply, %{state | users: reduce([user], state.users)}}
  end

  def handle_cast(%{"presence" => presence, "type" => "presence_change", "user" => user}, %{ref: nil} = state) do
    users = update_in(state.users, [user], &Map.put(&1, "presence", presence))
    {:noreply, %{state | users: users}}
  end

  def handle_info(%{"type" => "reconnect_url"}, state), do:
    {:noreply, state}

  def handle_info(%{"type" => "hello"}, %{robot: robot} = state) do
    Hedwig.Robot.handle_connect(robot)
    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, pid, reason}, %{conn: pid, conn_ref: ref} = state) do
    handle_network_failure(reason, state)
  end

  def handle_info(msg, %{robot: robot} = state) do
    Hedwig.Robot.handle_in(robot, msg)
    {:noreply, state}
  end

  def terminate(_reason, _state) do
    :ok
  end

  defp handle_network_failure(reason, %{robot: robot} = state) do
    case Hedwig.Robot.handle_disconnect(robot, reason) do
      {:disconnect, reason} ->
        {:stop, reason, state}
      {:reconnect, timeout} ->
        Process.send_after(self(), :rtm_connect, timeout)
        {:noreply, reset_state(state)}
      :reconnect ->
        Kernel.send(self(), :rtm_connect)
        {:noreply, reset_state(state)}
    end
  end

  defp slack_message(%Hedwig.Message{} = msg, overrides \\ %{}) do
    Map.merge(%{channel: msg.room, text: msg.text, type: msg.type}, overrides)
  end

  defp put_channel_user(channels, channel_id, user_id) do
    update_in(channels, [channel_id, "members"], &([user_id | &1]))
  end

  defp delete_channel_user(channels, channel_id, user_id) do
    update_in(channels, [channel_id, "members"], &(&1 -- [user_id]))
  end

  defp reduce(collection, acc) do
    Enum.reduce(collection, acc, fn item, acc ->
      Map.put(acc, item["id"], item)
    end)
  end

  defp reset_state(state) do
    %{state | conn: nil,
              conn_ref: nil,
              channels: %{},
              groups: %{},
              id: nil,
              name: nil,
              users: %{}}
  end
end

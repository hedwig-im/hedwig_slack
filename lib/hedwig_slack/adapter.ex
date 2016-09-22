defmodule Hedwig.Adapters.Slack do
  use Hedwig.Adapter

  alias HedwigSlack.{Connection, RTM}

  defmodule State do
    defstruct conn: nil,
              conn_ref: nil,
              channels: %{},
              groups: %{},
              id: nil,
              name: nil,
              opts: nil,
              robot: nil,
              users: %{}
  end

  def init({robot, opts}) do
    endpoint = Keyword.get(opts, :endpoint, :default)
    token = Keyword.get(opts, :token)

    case RTM.start(endpoint, token) do
      {:ok, data} ->
        handle_rtm_data(data)
        {:ok, conn, ref} = Connection.start(data["url"])
        {:ok, %State{conn: conn, conn_ref: ref, opts: opts, robot: robot}}
      {:error, _} = error ->
        error
    end
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

  def handle_info(%{"subtype" => "channel_join", "channel" => channel, "user" => user}, state) do
    channels = put_channel_user(state.channels, channel, user)
    {:noreply, %{state | channels: channels}}
  end

  def handle_info(%{"subtype" => "channel_leave", "channel" => channel, "user" => user}, state) do
    channels = delete_channel_user(state.channels, channel, user)
    {:noreply, %{state | channels: channels}}
  end

  def handle_info(%{"type" => "message", "user" => user} = msg, %{robot: robot, users: users} = state) do
    msg = %Hedwig.Message{
      ref: make_ref(),
      room: msg["channel"],
      text: msg["text"],
      type: "message",
      user: %Hedwig.User{
        id: user,
        name: users[user]["name"]
      }
    }

    if msg.text do
      Hedwig.Robot.handle_message(robot, msg)
    end

    {:noreply, state}
  end

  def handle_info({:channels, channels}, state) do
    {:noreply, %{state | channels: reduce(channels, state.channels)}}
  end

  def handle_info({:groups, groups}, state) do
    {:noreply, %{state | groups: reduce(groups, state.groups)}}
  end

  def handle_info({:self, %{"id" => id, "name" => name}}, state) do
    {:noreply, %{state | id: id, name: name}}
  end

  def handle_info({:users, users}, state) do
    {:noreply, %{state | users: reduce(users, state.users)}}
  end

  def handle_info(%{"type" => "presence_change", "user" => user}, %{id: user} = state), do:
    {:noreply, state}

  def handle_info(%{"presence" => presence, "type" => "presence_change", "user" => user}, state) do
    users = update_in(state.users, [user], &Map.put(&1, "presence", presence))
    {:noreply, %{state | users: users}}
  end

  def handle_info(%{"type" => "reconnect_url"}, state), do:
    {:noreply, state}

  def handle_info(%{"type" => "hello"}, %{robot: robot} = state) do
    Hedwig.Robot.after_connect(robot)
    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, pid, reason}, %{conn: pid, conn_ref: ref} = state) do
    {:stop, reason, state}
  end

  def handle_info(msg, %{robot: robot} = state) do
    Hedwig.Robot.handle_in(robot, msg)
    {:noreply, state}
  end

  def terminate(_reason, _state) do
    :ok
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

  defp handle_rtm_data(data) do
    Kernel.send(self(), {:channels, data["channels"]})
    Kernel.send(self(), {:groups, data["groups"]})
    Kernel.send(self(), {:self, data["self"]})
    Kernel.send(self(), {:users, data["users"]})
  end
end

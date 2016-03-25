defmodule Hedwig.Adapters.Slack do
  use Hedwig.Adapter

  alias Hedwig.Adapters.Slack.Connection

  defmodule State do
    defstruct conn: nil,
              opts: nil,
              robot: nil,
              users: %{},
              channels: %{}
  end

  def init({robot, opts}) do
    {:ok, conn} = Connection.start_link(opts)
    {:ok, %State{conn: conn, opts: opts, robot: robot}}
  end

  def handle_cast({:send, msg}, %{conn: conn} = state) do
    Connection.ws_send(conn, slack_message(msg))
    {:noreply, state}
  end

  def handle_cast({:reply, %{user: user, text: text} = msg}, %{conn: conn, users: users} = state) do
    msg = %{msg | text: "<@#{user}|#{users[user]["name"]}>: #{text}"}
    Connection.ws_send(conn, slack_message(msg))
    {:noreply, state}
  end

  def handle_cast({:emote, msg}, %{conn: conn} = state) do
    Connection.ws_send(conn, slack_message(msg))
    {:noreply, state}
  end

  def handle_info(%{"type" => "message"} = msg, %{conn: conn, robot: robot} = state) do
    IO.inspect msg
    IO.inspect state.users

    msg = %Hedwig.Message{
      adapter: {__MODULE__, self()},
      ref: make_ref(),
      room: msg["channel"],
      text: msg["text"],
      type: msg["type"],
      user: msg["user"]
    }
    Hedwig.Robot.handle_message(robot, msg)
    {:noreply, state}
  end

  def handle_info(%{"type" => "channel_created", "channel" => _channel}, state) do
    {:noreply, state}
  end

  def handle_info(%{"type" => "channel_joined", "channel" => _channel}, state) do
    {:noreply, state}
  end

  def handle_info(%{"type" => "message", "subtype" => "channel_join"}, state) do
    {:noreply, state}
  end

  def handle_info({:user, %{"id" => id} = user}, %{users: users} = state) do
    {:noreply, %{state | users: Map.put(users, id, user)}}
  end

  def handle_info(msg, state) do
    IO.inspect msg
    {:noreply, state}
  end

  defp slack_message(%Hedwig.Message{room: room, text: text, type: type}) do
    %{channel: room,
      text: text,
      type: type}
  end
end

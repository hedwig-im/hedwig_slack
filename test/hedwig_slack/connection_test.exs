defmodule HedwigSlack.ConnectionTest do
  use ExUnit.Case

  alias HedwigSlack.{Connection, WebSocketServer}

  setup do
    server = WebSocketServer.open(WebSocketServer)
    {:ok, server: server}
  end

  test "websocket connection", %{server: server} do
    {:ok, conn, _ref} = Connection.start("ws://localhost:#{server.port}/ws")
    assert_receive %{"type" => "hello"}

    :ok = Connection.ws_send(conn, %{type: "message"})

    assert_receive %{"ok" => true, "reply_to" => 1}

    :ok = Connection.close(conn)
  end
end

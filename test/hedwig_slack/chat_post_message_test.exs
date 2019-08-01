defmodule HedwigSlack.ChatPostMessageTest do
  use ExUnit.Case

  import Plug.Conn

  alias HedwigSlack.ChatPostMessage

  describe "chat.postMessage" do
    setup :setup_endpoint

    test "returns data when success", %{server: server} do
      token = "abc123"
      channel = "C1234567890"
      text = "Hello, world!"

      Bypass.expect server, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/chat.postMessage"

        resp(conn, 200, ~s({"ok":true, "channel": "#{channel}", "message": { "text": "#{text}"}}))
      end
      {:ok, %{status: 200, body: body}} = ChatPostMessage.post(token, channel, text)
      assert %{"ok" => true, "channel" => channel, "message" => %{"text" => text}} == body
    end

    test "returns error when server is down", %{server: server} do
      :ok = Bypass.down(server)
      assert {:error, :econnrefused} = ChatPostMessage.post("token", "channel", "text")
    end

    test "returns error when server goes down in-flight", %{server: server} do
      Bypass.expect server, fn _conn ->
        :ok = Bypass.pass(server)
        :ok = Bypass.down(server)
      end
      assert {:error, :closed} = ChatPostMessage.post("token", "channel", "text")
    end
  end

  defp setup_endpoint(_) do
    server = Bypass.open()
    :ok = Application.put_env(:hedwig_slack, :endpoint, "http://localhost:#{server.port}/api")

    {:ok, server: server}
  end
end

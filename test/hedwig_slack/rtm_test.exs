defmodule HedwigSlack.RTMTest do
  use ExUnit.Case

  import Plug.Conn

  alias HedwigSlack.RTM

  describe "rtm.connect" do
    setup :setup_endpoint

    test "returns data when success", %{server: server} do
      token = "abc123"

      Bypass.expect server, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/rtm.connect"
        assert conn.query_string == "token=#{token}"

        resp(conn, 200, ~s({"ok":true}))
      end

      {:ok, %{status: 200, body: body}} = RTM.connect(token)
      assert %{"ok" => true} == body
    end

    test "returns error when server is down", %{server: server} do
      :ok = Bypass.down(server)
      assert {:error, :econnrefused} = RTM.connect("token")
    end

    test "returns error when server goes down in-flight", %{server: server} do
      Bypass.expect server, fn _conn ->
        :ok = Bypass.pass(server)
        :ok = Bypass.down(server)
      end
      assert {:error, :closed} = RTM.connect("token")
    end
  end

  defp setup_endpoint(_) do
    server = Bypass.open()
    :ok = Application.put_env(:hedwig_slack, :endpoint, "http://localhost:#{server.port}/api")

    {:ok, server: server}
  end
end

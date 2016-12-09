defmodule HedwigSlack.WebAPITest do
  use ExUnit.Case

  import Plug.Conn

  alias HedwigSlack.WebAPI

  describe "Web API methods" do
    setup :setup_endpoint

    test "posts a message", %{server: server} do
      token = "abc123"

      Bypass.expect server, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/chat.postMessage"
        assert conn.query_string == ""
        assert get_req_header(conn, "content-type") == ["application/x-www-form-urlencoded; charset=utf-8"]

        resp(conn, 200, ~s({"ok":true}))
      end

      {:ok, %{status: 200, body: body}} = WebAPI.chat_postmessage(%{channel: "test", text: "hi", token: token})
      assert %{"ok" => true} == body
    end

    test "posts a me_message", %{server: server} do
      token = "abc123"

      Bypass.expect server, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/chat.meMessage"
        assert conn.query_string == ""
        assert get_req_header(conn, "content-type") == ["application/x-www-form-urlencoded; charset=utf-8"]

        resp(conn, 200, ~s({"ok":true}))
      end

      {:ok, %{status: 200, body: body}} = WebAPI.chat_memessage(%{channel: "test", text: "hi", token: token})
      assert %{"ok" => true} == body
    end
  end

  defp setup_endpoint(_) do
    server = Bypass.open()
    :ok = Application.put_env(:hedwig_slack, :endpoint, "http://localhost:#{server.port}/api")

    {:ok, server: server}
  end
end

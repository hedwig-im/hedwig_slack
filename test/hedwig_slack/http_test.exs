defmodule HedwigSlack.HTTPTest do
  use ExUnit.Case

  import Plug.Conn, only: [get_req_header: 2, read_body: 1, resp: 3]

  alias HedwigSlack.HTTP

  describe "making requests" do
    setup :setup_endpoint

    test "get/2", %{server: server} do
      token = "abc123"

      Bypass.expect server, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/rtm.start"
        assert conn.query_string == "token=#{token}"

        resp(conn, 200, ~s({"ok":true}))
      end

      {:ok, %{status: 200, body: body}} = HTTP.get("/rtm.start", query: [token: token])
      assert %{"ok" => true} == body
    end

    test "post/2", %{server: server} do
      token = "abc123"

      Bypass.expect server, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/rtm.start"
        assert conn.query_string == "token=#{token}"
        assert get_req_header(conn, "content-type") == ["application/octet-stream"]
        {:ok, ~s({"data":123}), conn} = read_body(conn)

        resp(conn, 201, ~s({"ok":true}))
      end

      {:ok, %{status: 201, body: body}} = HTTP.post("/rtm.start", query: [token: token], body: %{"data" => 123})
      assert %{"ok" => true} == body
    end

    test "put/2", %{server: server} do
      token = "abc123"

      Bypass.expect server, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/api/rtm.start"
        assert conn.query_string == "token=#{token}"
        {:ok, ~s({"data":123}), conn} = read_body(conn)

        resp(conn, 200, ~s({"ok":true}))
      end

      {:ok, %{status: 200, body: body}} = HTTP.put("/rtm.start", query: [token: token], body: %{"data" => 123})
      assert %{"ok" => true} == body
    end

    test "patch/2", %{server: server} do
      token = "abc123"

      Bypass.expect server, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/rtm.start"
        assert conn.query_string == "token=#{token}"
        {:ok, ~s({"data":123}), conn} = read_body(conn)

        resp(conn, 200, ~s({"ok":true}))
      end

      {:ok, %{status: 200, body: body}} = HTTP.patch("/rtm.start", query: [token: token], body: %{"data" => 123})
      assert %{"ok" => true} == body
    end

    test "delete/2", %{server: server} do
      token = "abc123"

      Bypass.expect server, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/rtm.start"
        assert conn.query_string == "token=#{token}"

        resp(conn, 200, ~s({"ok":true}))
      end

      {:ok, %{status: 200, body: body}} = HTTP.delete("/rtm.start", query: [token: token])
      assert %{"ok" => true} == body
    end

    test "form_post/2", %{server: server} do
      token = "abc123"

      Bypass.expect server, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/chat.postMessage"
        assert conn.query_string == ""
        assert get_req_header(conn, "content-type") == ["application/x-www-form-urlencoded; charset=utf-8"]
        resp(conn, 200, ~s({"ok":true}))
      end

      {:ok, %{status: 200, body: body}} = HTTP.form_post("/chat.postMessage", %{token: token})
      assert %{"ok" => true} == body
    end
  end

  defp setup_endpoint(_) do
    server = Bypass.open()
    :ok = Application.put_env(:hedwig_slack, :endpoint, "http://localhost:#{server.port}/api")

    {:ok, server: server}
  end
end

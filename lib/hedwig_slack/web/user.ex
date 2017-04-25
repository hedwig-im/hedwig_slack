defmodule HedwigSlack.User do
  use GenServer
  require Logger

  alias HedwigSlack.HTTP

  defmodule State do
    defstruct buffer: [],
              parent: nil,
              parent_ref: nil,
              request_opts: [],
              request_ref: nil,
              token: nil
  end

  def list(token, opts \\ []) do
    {:ok, pid} = GenServer.start(__MODULE__, {token, opts, self()})
    ref = Process.monitor(pid)
    {:ok, pid, ref}
  end

  def init({token, request_opts, parent}) do
    ref = Process.monitor(parent)
    GenServer.cast(self(), :fetch_user_list)

    {:ok, %State{token: token,
                 request_opts: request_opts,
                 parent: parent,
                 parent_ref: ref}}
  end

  def handle_cast(:fetch_user_list, %{token: token} = state) do
    {:ok, ref} = fetch_user_list(token, async: true, stream_to: self())
    Logger.info "Fetching user list. This could take a while depending on the size of your Slack team."
    {:noreply, %{state | request_ref: ref}}
  end

  def handle_info({:hackney_response, ref, {:status, 200, "OK"}}, %{request_ref: ref} = state) do
    {:noreply, state}
  end
  def handle_info({:hackney_response, ref, {:status, _, _}}, %{request_ref: ref} = state) do
    {:stop, }
  end

  def handle_info({:hackney_response, ref, {:headers, headers}}, %{request_ref: ref} = state) do
    {:noreply, state}
  end

  def handle_info({:hackney_response, ref, :done}, %{buffer: buffer, request_ref: ref} = state) do
    true = Process.demonitor(state.parent_ref)
    users = Poison.decode!(buffer)

    GenServer.cast(state.parent, {:users, users})

    {:noreply, state}
  end

  def handle_info({:hackney_response, ref, binary}, %{buffer: buffer, request_ref: ref} = state) do
    IO.write(".")
    {:noreply, %{state | buffer: buffer ++ [binary]}}
  end

  def fetch_user_list(token, opts) do
    HTTP.get("/users.list", [query: [token: token, presence: true]] ++ opts)
  end
end

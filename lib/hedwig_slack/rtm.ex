defmodule HedwigSlack.RTM do
  alias HedwigSlack.HTTP

  def start(token, opts \\ []) do
    HTTP.get("/rtm.start", query: [token: token] ++ opts)
  end
end

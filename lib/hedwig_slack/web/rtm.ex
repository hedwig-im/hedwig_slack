defmodule HedwigSlack.RTM do
  alias HedwigSlack.HTTP

  def connect(token, opts \\ []) do
    HTTP.get("/rtm.connect", query: [token: token] ++ opts)
  end
end

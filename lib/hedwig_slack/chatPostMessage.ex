defmodule HedwigSlack.ChatPostMessage do
  alias HedwigSlack.HTTP

  def post(token, channel, text, opts \\ []) do
    HTTP.post("/chat.postMessage", body: %{token: token, channel: channel, text: text})
  end
end

defmodule HedwigSlack.ChatPostMessage do
  alias HedwigSlack.HTTP

  def post(token, channel, attachments: attachments) do
    {:ok, _resp} = HTTP.post("/chat.postMessage", body: %{channel: channel, attachments: attachments}, headers: ["Content-Type": "application/json", "Authorization": "Bearer #{token}"])
  end

  def post(token, channel, blocks: blocks) do
    {:ok, _resp} = HTTP.post("/chat.postMessage", body: %{channel: channel, blocks: blocks}, headers: ["Content-Type": "application/json", "Authorization": "Bearer #{token}"])
  end
end

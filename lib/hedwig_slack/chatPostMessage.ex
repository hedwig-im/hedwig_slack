defmodule HedwigSlack.ChatPostMessage do
  alias HedwigSlack.HTTP

  def post(token, channel, text) do
    HTTP.post("/chat.postMessage", body: %{channel: channel, text: text}, headers: ["Content-Type": "application/json; charset=utf-8", "Authorization": "Bearer #{token}"])
  end

  def post(token, channel, attachments: attachments) do
    HTTP.post("/chat.postMessage", body: %{channel: channel, attachments: attachments}, headers: ["Content-Type": "application/json; charset=utf-8", "Authorization": "Bearer #{token}"])
  end

  def post(token, channel, blocks: blocks) do
    HTTP.post("/chat.postMessage", body: %{channel: channel, blocks: blocks}, headers: ["Content-Type": "application/json; charset=utf-8", "Authorization": "Bearer #{token}"])
  end
end

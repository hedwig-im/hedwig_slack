defmodule HedwigSlack.WebAPI do
  alias HedwigSlack.HTTP

  @doc "https://api.slack.com/methods/chat.meMessage"
  def chat_postmessage(%{token: _, channel: _, text: _} = args) do
    HTTP.form_post("/chat.postMessage", args)
  end

  @doc "https://api.slack.com/methods/chat.postMessage"
  def chat_memessage(%{token: _, channel: _, text: _} = args) do
    HTTP.form_post("/chat.meMessage", args)
  end
end

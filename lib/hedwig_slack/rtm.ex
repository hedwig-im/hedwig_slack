defmodule HedwigSlack.RTM do
  @endpoint "https://slack.com/api/rtm.start"

  def start(:default, token), do: start(@endpoint, token)
  def start(endpoint, token) do
    {:ok, 200, _headers, ref} = :hackney.get(rtm_endpoint(endpoint, token))

    case :hackney.body(ref) do
      {:ok, body} ->
        {:ok, _} = Poison.decode(body)
      {:error, _} = error ->
        error
    end
  end

  defp rtm_endpoint(endpoint, token), do: "#{endpoint}?token=#{token}"
end

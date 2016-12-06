defmodule HedwigSlack.HTTP do
  @endpoint "https://slack.com/api"

  def get(path, opts \\ []),
    do: request(:get, path, opts)

  def post(path, opts \\ []),
    do: request(:post, path, opts)

  def put(path, opts \\ []),
    do: request(:put, path, opts)

  def patch(path, opts \\ []),
    do: request(:patch, path, opts)

  def delete(path, opts \\ []),
    do: request(:delete, path, opts)

  def request(method, path, opts \\ []) do
    HTTPoison.start

    with {query, opts} = Keyword.pop(opts, :query, []),
         {req_headers, opts} = Keyword.pop(opts, :headers, []),
         {req_body, _} <- Keyword.pop(opts, :body),
         payload = encode(req_body),
         url <- url(path, query),
         {:ok, response} <- HTTPoison.request(method, url, payload, req_headers),
         %HTTPoison.Response{status_code: status, headers: headers, body: body} <- response do
      {:ok, %{status: status, headers: headers, body: Poison.decode!(body)}}
    else
      {:error, %HTTPoison.Error{reason: reason}} -> {:error, reason}
    end
  end

  def form_post(path, body) do
    request :post, path, [body: {:form, Map.to_list(body)}]
  end

  defp encode(nil), do: ""
  defp encode(data) when is_map(data), do: Poison.encode!(data)
  defp encode(data) when is_binary(data), do: Poison.encode!(data)
  defp encode(data) when is_tuple(data), do: data
  defp encode(data) do
    IO.inspect data
  end

  defp url(path, query) do
    uri = URI.parse(endpoint)
    query = encode_query(query)
    to_string(%{uri | path: uri.path <> path, query: query})
  end

  defp endpoint, do: Application.get_env(:hedwig_slack, :endpoint, @endpoint)

  defp encode_query(nil), do: nil
  defp encode_query(enum), do: URI.encode_query(enum)
end

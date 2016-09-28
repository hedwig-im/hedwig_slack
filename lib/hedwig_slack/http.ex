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
    {query, opts} = Keyword.pop(opts, :query)
    {req_headers, opts} = Keyword.pop(opts, :headers, [])
    {req_body, opts} = Keyword.pop(opts, :body)

    url = url(path, query)
    payload = if req_body, do: Poison.encode!(req_body), else: ""

    with {:ok, status, headers, ref} <- :hackney.request(method, url, req_headers, payload, opts),
         {:ok, body} <- :hackney.body(ref),
         {:ok, decoded} <- Poison.decode(body) do
      {:ok, %{status: status, headers: headers, body: decoded}}
    else
      {:error, _} = error ->
        error
      error ->
        error
    end
  end

  defp url(path, query) do
    endpoint = Application.get_env(:hedwig_slack, :endpoint, @endpoint)
    uri = URI.parse(endpoint)
    query = encode_query(query)
    to_string(%{uri | path: uri.path <> path, query: query})
  end

  defp encode_query(nil), do: nil
  defp encode_query(enum), do: URI.encode_query(enum)
end

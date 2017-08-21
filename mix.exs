defmodule HedwigSlack.Mixfile do
  use Mix.Project

  @version "1.0.0"

  def project do
    [app: :hedwig_slack,
     name: "Hedwig Slack",
     version: @version,
     elixir: "~> 1.1",
     elixirc_paths: elixirc_paths(Mix.env),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     package: package(),
     description: "A Slack adapter for Hedwig",
     deps: deps()]
  end

  def application do
    [mod: {HedwigSlack, []},
     applications: [
      :logger,
      :hackney,
      :hedwig,
      :poison,
      :websocket_client
    ]]
  end

  defp deps do
    [{:hackney, "~> 1.9"},
     {:hedwig, "~> 1.0"},
     {:poison, "~> 3.0"},
     {:websocket_client, "~> 1.3"},

     # Test dependencies
     {:bypass, "~> 0.5", only: :test}]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [files: ["lib", "mix.exs", "README*", "LICENSE*"],
     maintainers: ["Sonny Scroggin"],
     licenses: ["MIT"],
     links: %{
       "GitHub" => "https://github.com/hedwig-im/hedwig_slack"
     }]
  end
end

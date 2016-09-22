defmodule HedwigSlack.Mixfile do
  use Mix.Project

  @version "0.1.0"

  def project do
    [app: :hedwig_slack,
     name: "Hedwig Slack",
     version: @version,
     elixir: "~> 1.1",
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
    [{:hackney, "~> 1.6"},
     {:hedwig, github: "hedwig-im/hedwig", ref: "a453847"},
     {:poison, "~> 2.0"},
     {:websocket_client, "~> 1.1"}]
  end

  defp package do
    [files: ["lib", "priv", "mix.exs", "README*", "readme*", "LICENSE*", "license*"],
     maintainers: ["Sonny Scroggin"],
     licenses: ["MIT"],
     links: %{
       "GitHub" => "https://github.com/hedwig-im/hedwig_slack"
     }]
  end
end

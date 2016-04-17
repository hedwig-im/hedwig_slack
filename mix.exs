defmodule HedwigSlack.Mixfile do
  use Mix.Project

  def project do
    [app: :hedwig_slack,
     version: "0.1.0",
     elixir: "~> 1.1",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger, :gun, :hedwig, :poison]]
  end

  defp deps do
    [{:gun, "1.0.0-pre.1"},
     {:hedwig, "~> 1.0.0-rc.4"},
     {:poison, "~> 2.0"}]
  end
end

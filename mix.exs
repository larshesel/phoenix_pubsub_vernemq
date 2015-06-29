defmodule PhoenixPubsubVernemq.Mixfile do
  use Mix.Project

  def project do
    [app: :phoenix_pubsub_vernemq,
     version: "0.0.3",
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     package: package,
     description: """
     The VerneMQ MQTT pubsub adapter for the Phoenix framework
     """]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger]]
  end

  defp deps do
    [{:phoenix, github: "phoenixframework/phoenix"},
     {:vmq_commons, git: "https://github.com/erlio/vmq_commons.git", compile: "rebar compile"}]
  end

  defp package do
    [contributors: ["Lars Hesel Christensen"],
     licenses: ["Apache v2.0"],
     links: %{github: "https://github.com/larshesel/phoenix_pubsub_vernemq"}]
  end
end

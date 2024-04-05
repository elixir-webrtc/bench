defmodule WebRTCBench.MixProject do
  use Mix.Project

  def project do
    [
      app: :webrtc_bench,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {WebRTCBench, []}
    ]
  end

  defp deps do
    [
      {:ex_webrtc, github: "elixir-webrtc/ex_webrtc"},
      {:ex_ice, github: "elixir-webrtc/ex_ice", branch: "ta-timeout-opt", override: true},
      {:plug, "~> 1.15.0"},
      {:bandit, "~> 1.4.0"},
      {:req, "~> 0.4.0"}
    ]
  end
end

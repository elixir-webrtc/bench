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
      extra_applications: [:logger, :wx, :observer, :runtime_tools],
      mod: {WebRTCBench, []}
    ]
  end

  defp deps do
    [
      {:ex_webrtc, "~> 0.2.0"},
      {:plug, "~> 1.15.0"},
      {:bandit, "~> 1.4.0"},
      {:req, "~> 0.4.0"},
      {:statistics, "~> 0.6.0"}
    ]
  end
end

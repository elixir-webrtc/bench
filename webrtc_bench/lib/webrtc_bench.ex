defmodule WebRTCBench do
  use Application

  require Logger

  alias __MODULE__.{Client, Server}

  @impl true
  def start(_type, _args) do
    Logger.info("Starting WebRTC Bench with system pid #{System.pid()}")

    client_address = Application.get_env(:webrtc_bench, :client_address)
    server_address = Application.get_env(:webrtc_bench, :server_address)

    children =
      case {client_address, server_address} do
        {nil, nil} ->
          Logger.warning("Neither client or server address env var was set")
          []
        {address, nil} -> [{Client, address}]
        {nil, address} -> [{Server, address}]
        {_, _} -> raise "Both client and server address env vars were set"
      end

    Supervisor.start_link(children, strategy: :one_for_one, name: WebRTCBench.Supervisor)
  end
end

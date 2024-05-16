defmodule WebRTCBench do
  use Application

  require Logger

  alias __MODULE__.{Client, Server}
  alias __MODULE__.PeerHandler.StatLogger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting WebRTC Bench, OS pid: #{System.pid()}")

    address = Application.fetch_env!(:webrtc_bench, :address)
    type = Application.get_env(:webrtc_bench, :type)

    children =
      case type do
        "server" ->
          [{Server, address}]

        "client" ->
          [{Client, address}]

        _other ->
          Logger.warning("Pass either 'server' or 'client' as a value for $WB_TYPE")
          []
      end

    ph_supervisor = {DynamicSupervisor, name: __MODULE__.PeerHandlerSupervisor}
    children = [ph_supervisor, StatLogger] ++ children
    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__.Supervisor)
  end
end

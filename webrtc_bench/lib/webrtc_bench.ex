defmodule WebRTCBench do
  use Application

  require Logger

  alias __MODULE__.{Client, Server}
  alias __MODULE__.PeerHandler.StatLogger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting WebRTC Bench, OS pid: #{System.pid()}")

    address = Application.get_env(:webrtc_bench, :address)

    handler =
      case System.argv() do
        ["server"] -> {Server, address}
        ["client"] -> {Client, address}
        _other -> raise "Pass either 'server' or 'client' as a command line argument"
      end

    ph_supervisor = {DynamicSupervisor, name: __MODULE__.PeerHandlerSupervisor}
    children = [handler, ph_supervisor, StatLogger]
    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__.Supervisor)
  end
end

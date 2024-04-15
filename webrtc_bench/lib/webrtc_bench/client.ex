defmodule WebRTCBench.Client do
  use Task

  require Logger

  alias WebRTCBench.{PeerHandler, PeerHandlerSupervisor}

  def start(address) do
    Task.start(__MODULE__, :run, [address])
  end

  def start_link(address) do
    Task.start_link(__MODULE__, :run, [address])
  end

  def run(address) do
    {:ok, peer_handler} =
      DynamicSupervisor.start_child(PeerHandlerSupervisor, {PeerHandler, :client})

    offer = PeerHandler.start_negotiation(peer_handler)

    Logger.info("Attempting to connect to #{address}")

    response = Req.post!("http://#{address}/", json: %{offer: offer})

    :ok = PeerHandler.finish_negotiation(peer_handler, response.body["answer"])
  end
end

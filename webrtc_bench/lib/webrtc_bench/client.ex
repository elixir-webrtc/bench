defmodule WebRTCBench.Client do
  use Task

  require Logger

  alias WebRTCBench.PeerHandler

  def start_link(address) do
    Task.start_link(__MODULE__, :run, [address])
  end

  def run(address) do
    opts = Application.get_env(:webrtc_bench, :opts)
    {:ok, peer_handler} = PeerHandler.start_link(:client, opts)
    offer = PeerHandler.start_negotiation(peer_handler)

    Logger.info("Attempting to connect to #{address}")

    response = Req.post!("http://#{address}/", json: %{offer: offer})

    :ok = PeerHandler.finish_negotiation(peer_handler, response.body["answer"])
  end
end

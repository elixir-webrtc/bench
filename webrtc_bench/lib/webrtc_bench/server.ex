defmodule WebRTCBench.Server do
  defmodule ServerPlug do
    import Plug.Conn
     
    alias WebRTCBench.PeerHandler

    @behaviour Plug

    @impl true
    def init(opts), do: opts

    @impl true
    def call(conn, _opts) do
      {:ok, body, conn} = read_body(conn)
      body = Jason.decode!(body)

      opts = Application.get_env(:webrtc_bench, :server)
      {:ok, peer_handler} = PeerHandler.start_link(:server, opts)
      answer = PeerHandler.continue_negotiation(peer_handler, body["offer"])

      response_body = Jason.encode!(%{answer: answer})
      conn
      |> put_resp_content_type("application/json")
      |> resp(200, response_body)
      |> send_resp()
    end
  end

  def child_spec(arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [arg]},
      restart: :transient
    }
  end

  def start_link(address) do
    [ip, port] = String.split(address, ":")
    port = String.to_integer(port)
    {:ok, ip} =
      ip
      |> String.to_charlist()
      |> :inet.parse_address()

    Bandit.start_link(plug: ServerPlug, scheme: :http, ip: ip, port: port)
  end
end

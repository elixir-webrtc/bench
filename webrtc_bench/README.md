# WebRTC Benchmark

This repo contains a simple benchmark app for the `ex_webrtc` library.

## How to run

Run the same app separately on two Elixir nodes, one as a server and one as a client.

Server:

```shell
# the server will listen on http://127.0.0.1:5002/
WB_TYPE=server mix run --no-halt
```

Client:

```shell
# sent request with offer to http://127.0.0.1:8001
export WB_VIDEO_TRACKS = 10
WB_TYPE=client mix run --no-halt
```

The client will start the negotiation with the server using a single PeerConnection. Number of negotiated tracks and the size and frequency of
sent packets are dependent on configuration via env variables (independent between the client and the server, see the `config/runtime.exs`).
Packets' payload is artificailly generated, all of the packets have the same size and the frequency is constant.

> [!WARNING]
> The number of audio/video tracks sent by the client must be positive and greater than or equal to the number of audio/video tracks sent by the server.
> Otherwise, the negotiation will fail.

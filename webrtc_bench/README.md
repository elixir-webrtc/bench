# WebRTC Benchmark

This repo contains a simple benchmark app for the `ex_webrtc` library.

## How to run

Run the same app separately on two Elixir nodes, one as a server and one as a client.

For both cases, start by fetching deps

```shell
mix deps.get
```

Server:

```shell
# the server will listen on http://127.0.0.1:8001/
export WB_SERVER="127.0.0.1:8001"

mix run --no-halt
```

or run `iex -S mix` and call the function directly:

```elixir
WebRTCBench.server("127.0.0.1:8001")
```

Client:

```shell
# sent request with offer to http://127.0.0.1:8001
export WB_CLIENT="127.0.0.1:8001"

mix run --no-halt
```

or, from `iex -S mix`

```elixir
WebRTCBench.client("127.0.0.1:8001")
```

The client will start the negotiation with the server using a single PeerConnection. Number of negotiated tracks and the size and frequency of
sent packets are dependent on configuration via env variables (see `config/runtime.exs`). Packets' payload is zeroed and all of the packets have the same size.

## Example

I assume that the current working directory is `bench/webrtc_bench`.

On one machine, run

```shell
export WB_AUDIO_TRACKS=0  # by default 1
export WB_VIDEO_TRACKS=0  # by default 1
export WB_SERVER="0.0.0.0:5002"

mix deps.get
mix run --no-halt
```

On the other machine, run

```shell
export WB_AUDIO_TRACKS=0
export WB_VIDEO_TRACKS=10
export WB_VIDEO_SIZE=1200  # by default 1000
export WB_VIDEO_FREQUENCY=180  # by default 200
export WB_CLIENT="192.168.0.1:5002"  # address of the first machine

mix deps.get
mix run --no-halt
```

The second machine will start the negotiation and then start sending 10 video tracks, around 200 packets with 1200 bytes of payload for every track.

> [!WARNING]
> The number of audio/video tracks sent by the client must be greater than or equal to the number of audio/video tracks sent by the server.
> Otherwise, the negotiation will fail.

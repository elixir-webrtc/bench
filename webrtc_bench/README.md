# WebRTC Benchmark

This repo contains a simple benchmark app for the `ex_webrtc` library.

## How to run

Run the same app separately on two Elixir nodes, one as a server and one as a client.

Server:

```shell
# the server will listen on http://127.0.0.1:8001/
export WB_SERVER="127.0.0.1:8001"

mix run --no-halt
```

or run `iex -S mix` and the function directly:

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

The client will start the negotiation with the server. Number of negotiated tracks and the size and frequency of sent packets are dependent
on configuration in `config/runtime.exs`.

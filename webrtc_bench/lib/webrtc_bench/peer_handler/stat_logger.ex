defmodule WebRTCBench.PeerHandler.StatLogger do
  use GenServer

  require Logger

  @log_interval 2000

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def record_packet(id, packet) do
    GenServer.cast(__MODULE__, {:record_packet, id, packet})
  end

  @impl true
  def init(_) do
    schedule_log()

    {:ok, initial_state()}
  end

  @impl true
  def handle_cast({:record_packet, id, packet}, state) do
    payload_len = byte_size(packet.payload)
    bytes = Map.update(state.bytes, id, 0, &(&1 + payload_len))

    # latency in ms
    # we keep all of the latencies in a single array
    <<timestamp::128, _rest::binary>> = packet.payload
    latency = (System.os_time(:nanosecond) - timestamp) / 1_000_000
    latencies = [latency | state.latencies]

    state = %{bytes: bytes, latencies: latencies}
    {:noreply, state}
  end

  @impl true
  def handle_info(:log, %{initial?: true} = state) do
    schedule_log()

    {:noreply, state}
  end

  @impl true
  def handle_info(:log, state) do
    schedule_log()

    bitrates = Enum.map(state.bytes, fn {_k, v} -> v * 8 / @log_interval * 1000 end)

    bitrate_metrics =
      bitrates
      |> calculate_metrics()
      |> Map.new(fn {k, v} -> {k, bitrate_to_str(v)} end)

    latency_metrics =
      state.latencies
      |> calculate_metrics(["total"])
      |> Map.new(fn {k, v} -> {k, "#{v} ms"} end)

    Logger.info("""
    Stats (incoming tracks):
      Bitrate: #{metrics_to_str(bitrate_metrics)}
      Latency: #{metrics_to_str(latency_metrics)}
    """)

    {:noreply, initial_state()}
  end

  defp initial_state() do
    %{
      initial?: true,
      bytes: %{},
      latencies: []
    }
  end

  defp calculate_metrics(values, excluded \\ []) do
    %{
      "total" => Statistics.sum(values),
      "min" => Statistics.min(values),
      "max" => Statistics.max(values),
      "mean" => Statistics.mean(values),
      "median" => Statistics.median(values),
      "99th %" => Statistics.percentile(values, 99)
    }
    |> Map.drop(excluded)
  end

  defp metrics_to_str(metrics) do
    metrics
    |> Enum.map(fn {k, v} -> "#{k} = #{v}" end)
    |> Enum.join(", ")
  end

  defp bitrate_to_str(bitrate) when bitrate < 1000, do: "#{bitrate} bit/s"
  defp bitrate_to_str(bitrate) when bitrate < 1_000_000, do: "#{bitrate / 1000} kbit/s"
  defp bitrate_to_str(bitrate), do: "#{bitrate / 1_000_000} mbit/s"

  defp schedule_log, do: Process.send_after(self(), :log, @log_interval)
end

defmodule WebRTCBench.PeerHandler.Sender do
  use GenServer

  alias ExWebRTC.PeerConnection
  alias ExRTP.Packet

  @nano_in_sec System.convert_time_unit(1, :second, :nanosecond)

  def start_link(pc, track_id, clock_rate, opts) do
    GenServer.start_link(__MODULE__, {pc, track_id, clock_rate, opts})
  end

  @impl true
  def init({pc, track_id, clock_rate, opts}) do
    interval = div(@nano_in_sec, opts.frequency)
    now = now()

    state = %{
      pc: pc,
      track_id: track_id,
      size: opts.size,
      interval: interval,
      clock_rate: clock_rate,
      seq_no: 0,
      base_time: now,
      next_time: now + interval
    }

    Process.send_after(self(), :send_packet, Enum.random(1..1000))

    {:ok, state}
  end

  @impl true
  def handle_info(:send_packet, state) do
    now = now()
    Process.send_after(self(), :send_packet, get_send_delay(now, state))

    timestamp = get_timestamp(now, state)

    payload_len = state.size * 8 - 128
    payload = <<now::128, 0::size(payload_len)>>

    packet = Packet.new(payload, timestamp: timestamp, sequence_number: state.seq_no)
    PeerConnection.send_rtp(state.pc, state.track_id, packet)

    state = %{state | next_time: state.next_time + state.interval, seq_no: state.seq_no + 1}
    {:noreply, state}
  end

  defp now(), do: System.os_time(:nanosecond)

  defp get_send_delay(now, state) do
    diff = state.next_time - now

    (state.interval + diff)
    |> System.convert_time_unit(:nanosecond, :millisecond)
    |> max(0)
  end

  defp get_timestamp(now, state) do
    diff = now - state.base_time
    div(diff * state.clock_rate, @nano_in_sec)
  end
end

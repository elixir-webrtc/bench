defmodule WebRTCBench.PeerHandler do
  use GenServer, restart: :temporary

  require Logger

  alias ExWebRTC.{MediaStreamTrack, PeerConnection, SessionDescription, RTPCodecParameters}
  alias __MODULE__.Sender

  @log_interval 2000

  @ice_servers [
    %{urls: "stun:stun.l.google.com:19302"}
  ]

  @video_codec %RTPCodecParameters{
    payload_type: 96,
    mime_type: "video/VP8",
    clock_rate: 90_000
  }

  @audio_codec %RTPCodecParameters{
    payload_type: 111,
    mime_type: "audio/opus",
    clock_rate: 48_000,
    channels: 2
  }

  def start(type) do
    GenServer.start(__MODULE__, type)
  end

  def start_link(type) do
    GenServer.start_link(__MODULE__, type)
  end

  def start_negotiation(peer_handler) do
    GenServer.call(peer_handler, :start_negotiation)
  end

  def continue_negotiation(peer_handler, offer) do
    GenServer.call(peer_handler, {:continue_negotiation, offer})
  end

  def finish_negotiation(peer_handler, answer) do
    GenServer.call(peer_handler, {:finish_negotiation, answer})
  end

  @impl true
  def init(type) do
    opts = Application.get_env(:webrtc_bench, :opts)

    {:ok, pc} =
      PeerConnection.start_link(
        ice_servers: @ice_servers,
        audio_codecs: [@audio_codec],
        video_codecs: [@video_codec]
      )

    Logger.info("Started PeerConnection, #{inspect(pc)}")

    audio_tracks =
      for _ <- 1..opts.audio.tracks//1 do
        track = MediaStreamTrack.new(:audio)
        {:ok, _sender} = PeerConnection.add_track(pc, track)
        track
      end

    Logger.info("Added #{opts.audio.tracks} audio track(s) to #{inspect(pc)}")

    video_tracks =
      for _ <- 1..opts.video.tracks//1 do
        track = MediaStreamTrack.new(:video)
        {:ok, _sender} = PeerConnection.add_track(pc, track)
        track
      end

    Logger.info("Added #{opts.video.tracks} video track(s) to #{inspect(pc)}")

    state = %{
      pc: pc,
      type: type,
      audio_tracks: audio_tracks,
      video_tracks: video_tracks,
      audio_opts: Map.take(opts.audio, [:size, :frequency]),
      video_opts: Map.take(opts.video, [:size, :frequency]),
      bytes_received: %{},
      last_timestamp: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:start_negotiation, _from, %{type: :client} = state) do
    {:ok, offer} = PeerConnection.create_offer(state.pc)
    :ok = PeerConnection.set_local_description(state.pc, offer)

    desc = get_local_description(state.pc)

    Logger.info("Sent offer from #{inspect(state.pc)}")

    {:reply, desc, state}
  end

  @impl true
  def handle_call({:continue_negotiation, offer}, _from, %{type: :server} = state) do
    offer = SessionDescription.from_json(offer)

    Logger.info("Received offer for #{inspect(state.pc)}")

    :ok = PeerConnection.set_remote_description(state.pc, offer)
    {:ok, answer} = PeerConnection.create_answer(state.pc)
    :ok = PeerConnection.set_local_description(state.pc, answer)

    desc = get_local_description(state.pc)

    Logger.info("Sent answer from #{inspect(state.pc)}")

    {:reply, desc, state}
  end

  @impl true
  def handle_call({:finish_negotiation, answer}, _from, %{type: :client} = state) do
    answer = SessionDescription.from_json(answer)
    :ok = PeerConnection.set_remote_description(state.pc, answer)

    Logger.info("Received answer for #{inspect(state.pc)}")

    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:ex_webrtc, _from, msg}, state) do
    state = handle_webrtc_msg(msg, state)
    {:noreply, state}
  end

  @impl true
  def handle_info(:log, state) do
    Process.send_after(self(), :log, @log_interval)

    byte_rates = Enum.map(state.bytes_received, fn {_k, v} -> v / @log_interval * 1000 end)

    {total_bitrate, avg_bitrate, min_bitrate, max_bitrate} =
      case length(byte_rates) do
        0 ->
          [0, 0, 0, 0]
          |> Enum.map(&bytes_to_bitrate/1)
          |> List.to_tuple()

        len ->
          min_bitrate = Enum.min(byte_rates) |> bytes_to_bitrate()
          max_bitrate = Enum.max(byte_rates) |> bytes_to_bitrate()
          total_bytes = Enum.sum(byte_rates)
          total_bitrate = total_bytes |> bytes_to_bitrate()
          avg_bitrate = (total_bytes / len) |> bytes_to_bitrate()
          {total_bitrate, avg_bitrate, min_bitrate, max_bitrate}
      end

    Logger.info(
      "Incoming bitrate: total = #{total_bitrate}, avg = #{avg_bitrate}, min = #{min_bitrate}, max = #{max_bitrate}"
    )

    bytes_received = Map.new(state.bytes_received, fn {k, _v} -> {k, 0} end)
    {:noreply, %{state | bytes_received: bytes_received}}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def terminate(reason, state) do
    Logger.warning(
      "PeerHandler for PeerConnection #{inspect(state.pc)} terminated with reason #{inspect(reason)}"
    )
  end

  defp handle_webrtc_msg({:connection_state_change, :connected}, state) do
    Logger.info("Connection established for #{inspect(state.pc)}, starting sending tracks")

    for %{id: id} <- state.audio_tracks do
      Sender.start_link(state.pc, id, @audio_codec.clock_rate, state.audio_opts)
    end

    for %{id: id} <- state.video_tracks do
      Sender.start_link(state.pc, id, @video_codec.clock_rate, state.video_opts)
    end

    Process.send_after(self(), :log, @log_interval)
    state
  end

  defp handle_webrtc_msg({:track, %{id: id}}, state) do
    bytes_received = Map.put(state.bytes_received, id, 0)
    %{state | bytes_received: bytes_received}
  end

  defp handle_webrtc_msg({:rtp, id, packet}, state) do
    bytes_received = Map.update!(state.bytes_received, id, &(&1 + byte_size(packet.payload)))
    %{state | bytes_received: bytes_received}
  end

  defp handle_webrtc_msg(_msg, state), do: state

  defp get_local_description(pc) do
    wait_for_candidates()

    pc
    |> PeerConnection.get_local_description()
    |> SessionDescription.to_json()
  end

  defp wait_for_candidates() do
    receive do
      {:ex_webrtc, _from, {:ice_gathering_state_change, :complete}} -> :ok
    after
      2000 -> raise "Candiate gathering took unexpectedly long"
    end
  end

  defp bytes_to_bitrate(bytes), do: format_bitrate(bytes * 8)

  defp format_bitrate(bitrate) when bitrate < 1000, do: "#{bitrate} bit/s"
  defp format_bitrate(bitrate) when bitrate < 1_000_000, do: "#{bitrate / 1000} kbit/s"
  defp format_bitrate(bitrate), do: "#{bitrate / 1_000_000} mbit/s"
end

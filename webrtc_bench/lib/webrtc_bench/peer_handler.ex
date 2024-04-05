defmodule WebRTCBench.PeerHandler do
  use GenServer, restart: :temporary

  require Logger

  alias ExWebRTC.{MediaStreamTrack, PeerConnection, SessionDescription, RTPCodecParameters}

  @log_interval 2000

  @ice_servers [
    %{urls: "stun:stun.l.google.com:19302"}
  ]

  @video_codecs [
    %RTPCodecParameters{
      payload_type: 96,
      mime_type: "video/VP8",
      clock_rate: 90_000
    }
  ]

  @audio_codecs [
    %RTPCodecParameters{
      payload_type: 111,
      mime_type: "audio/opus",
      clock_rate: 48_000,
      channels: 2
    }
  ]

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
        audio_codecs: @audio_codecs,
        video_codecs: @video_codecs
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
      bytes_received: 0
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
    bitrate = round(state.bytes_received * 8 / @log_interval * 1000)
    bitrate_str = bitrate_to_str(bitrate)
    Logger.info("Incoming bitrate: #{bitrate_str}")

    {:noreply, %{state | bytes_received: 0}}
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
    Logger.info("Connection established for #{inspect(state.pc)}")

    for %{id: id} <- state.audio_tracks do
      Logger.info("Starting sending for audio track #{inspect(id)}")
      start_sending(state.pc, id, state.audio_opts)
    end

    for %{id: id} <- state.video_tracks do
      Logger.info("Starting sending for video track #{inspect(id)}")
      start_sending(state.pc, id, state.video_opts)
    end

    Process.send_after(self(), :log, @log_interval)
    state
  end

  defp handle_webrtc_msg({:rtp, _id, packet}, state) do
    bytes_received = state.bytes_received + byte_size(packet.payload)
    %{state | bytes_received: bytes_received}
  end

  defp handle_webrtc_msg(_msg, state), do: state

  defp get_local_description(pc) do
    wait_for_candidates(1)

    pc
    |> PeerConnection.get_local_description()
    |> SessionDescription.to_json()
  end

  defp wait_for_candidates(0), do: :ok

  defp wait_for_candidates(n) do
    receive do
      {:ex_webrtc, _from, {:ice_candidate, _}} -> wait_for_candidates(n - 1)
    after
      500 -> raise "Candiate gathering took unexpectedly long"
    end
  end

  defp start_sending(pc, track_id, opts) do
    {:ok, pid} =
      Task.start_link(fn ->
        payload = <<0::opts.size*8>>
        packet = ExRTP.Packet.new(payload, sequence_number: Enum.random(0..0xFFFF))
        time = div(1000, opts.frequency)

        send_packet(pc, track_id, packet, time)
      end)

    send(pid, :send)
  end

  defp send_packet(pc, track_id, packet, time) do
    receive do
      :send ->
        Process.send_after(self(), :send, time)
        PeerConnection.send_rtp(pc, track_id, packet)

        packet = %{packet | sequence_number: packet.sequence_number + 1}
        send_packet(pc, track_id, packet, time)
    end
  end

  defp bitrate_to_str(bitrate) when bitrate < 1000, do: "#{bitrate} bit/s"
  defp bitrate_to_str(bitrate) when bitrate < 1_000_000, do: "#{bitrate / 1000} kbit/s"
  defp bitrate_to_str(bitrate), do: "#{bitrate / 1_000_000} mbit/s"
end

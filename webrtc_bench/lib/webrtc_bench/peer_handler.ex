defmodule WebRTCBench.PeerHandler do
  use GenServer, restart: :temporary

  require Logger

  alias ExWebRTC.{MediaStreamTrack, PeerConnection, SessionDescription, RTPCodecParameters}
  alias __MODULE__.{StatLogger, Sender}

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

    audio_tracks = setup_tracks(pc, :audio, opts)
    video_tracks = setup_tracks(pc, :video, opts)

    state = %{
      pc: pc,
      type: type,
      audio_tracks: audio_tracks,
      video_tracks: video_tracks,
      audio_opts: Map.take(opts.audio, [:size, :frequency]),
      video_opts: Map.take(opts.video, [:size, :frequency])
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:start_negotiation, _from, %{type: :client} = state) do
    {:ok, offer} = PeerConnection.create_offer(state.pc)
    :ok = PeerConnection.set_local_description(state.pc, offer)

    desc = get_local_description(state.pc)

    Logger.debug("""
    Sent offer from #{inspect(state.pc)}, offer:
    #{desc["sdp"]}
    """)

    {:reply, desc, state}
  end

  @impl true
  def handle_call({:continue_negotiation, offer}, _from, %{type: :server} = state) do
    offer = SessionDescription.from_json(offer)

    Logger.debug("""
    Received offer for #{inspect(state.pc)}, offer:
    #{offer.sdp}
    """)

    :ok = PeerConnection.set_remote_description(state.pc, offer)
    {:ok, answer} = PeerConnection.create_answer(state.pc)
    :ok = PeerConnection.set_local_description(state.pc, answer)

    desc = get_local_description(state.pc)

    Logger.debug("""
    Sent answer from #{inspect(state.pc)}, answer:
    #{desc["sdp"]}
    """)

    {:reply, desc, state}
  end

  @impl true
  def handle_call({:finish_negotiation, answer}, _from, %{type: :client} = state) do
    answer = SessionDescription.from_json(answer)
    :ok = PeerConnection.set_remote_description(state.pc, answer)

    Logger.debug("""
    Received answer for #{inspect(state.pc)}, answer:
    #{answer.sdp}
    """)

    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:ex_webrtc, _from, msg}, state) do
    handle_webrtc_msg(msg, state)
    {:noreply, state}
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
  end

  defp handle_webrtc_msg({:rtp, id, packet}, _state), do: StatLogger.record_packet(id, packet)

  defp handle_webrtc_msg(_msg, _state), do: :ok

  defp setup_tracks(pc, type, opts) do
    tracks =
      for _ <- 1..opts[type].tracks//1 do
        track = MediaStreamTrack.new(type)
        {:ok, _sender} = PeerConnection.add_track(pc, track)
        track
      end

    Logger.info("""
    Added #{opts[type].tracks} #{Atom.to_string(type)} track(s) to #{inspect(pc)}
    Packet size = #{opts[type].size} bytes, target frequency = #{opts[type].frequency} packets/s
    """)

    tracks
  end

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
end

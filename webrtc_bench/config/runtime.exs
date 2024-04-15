import Config

config :webrtc_bench,
  client_address: System.get_env("WB_CLIENT"),
  server_address: System.get_env("WB_SERVER"),
  opts: %{
    audio: %{
      tracks: System.get_env("WB_AUDIO_TRACKS", "1") |> String.to_integer(),
      size: System.get_env("WB_AUDIO_SIZE", "150") |> String.to_integer(),
      frequency: System.get_env("WB_AUDIO_FREQUENCY", "200") |> String.to_integer()
    },
    video: %{
      tracks: System.get_env("WB_VIDEO_TRACKS", "1") |> String.to_integer(),
      size: System.get_env("WB_VIDEO_SIZE", "1000") |> String.to_integer(),
      frequency: System.get_env("WB_VIDEO_FREQUENCY", "200") |> String.to_integer()
    }
  }

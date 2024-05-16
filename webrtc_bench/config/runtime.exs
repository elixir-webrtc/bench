import Config

config :webrtc_bench,
  type: System.get_env("WB_TYPE"),
  address: System.get_env("WB_ADDRESS", "127.0.0.1:5002"),
  opts: %{
    audio: %{
      tracks: System.get_env("WB_AUDIO_TRACKS", "0") |> String.to_integer(),
      size: System.get_env("WB_AUDIO_SIZE", "150") |> String.to_integer(),
      frequency: System.get_env("WB_AUDIO_FREQUENCY", "200") |> String.to_integer()
    },
    video: %{
      tracks: System.get_env("WB_VIDEO_TRACKS", "0") |> String.to_integer(),
      size: System.get_env("WB_VIDEO_SIZE", "1000") |> String.to_integer(),
      frequency: System.get_env("WB_VIDEO_FREQUENCY", "200") |> String.to_integer()
    }
  }

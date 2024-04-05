import Config

config :webrtc_bench,
  client_address: System.get_env("WB_CLIENT"),
  server_address: System.get_env("WB_SERVER"),
  opts: %{
    audio: %{
      tracks: System.get_env("WB_TRACKS", "1") |> String.to_integer(),
      size: System.get_env("WB_SIZE", "150") |> String.to_integer(),
      frequency: System.get_env("WB_FREQUENCY", "200") |> String.to_integer()
    },
    video: %{
      tracks: System.get_env("WB_TRACKS", "1") |> String.to_integer(),
      size: System.get_env("WB_SIZE", "1000") |> String.to_integer(),
      frequency: System.get_env("WB_FREQUENCY", "200") |> String.to_integer()
    }
  }

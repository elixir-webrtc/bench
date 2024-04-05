import Config

config :webrtc_bench,
  client_address: System.get_env("WB_CLIENT"),
  server_address: System.get_env("WB_SERVER"),
  client: %{
    audio: %{
      tracks: 1,
      size: 150,
      frequency: 200
    },
    video: %{
      tracks: 1,
      size: 1000,
      frequency: 200
    }
  },
  server: %{
    audio: %{
      tracks: 1,
      size: 150,
      frequency: 200
    },
    video: %{
      tracks: 1,
      size: 1000,
      frequency: 200
    }
  }

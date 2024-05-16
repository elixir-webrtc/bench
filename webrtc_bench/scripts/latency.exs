# requires format:
# "#{track_id} #{timestamp_in_ms} #{latency_in_ms}" split by newlines

Mix.install([{:statistics, "~> 0.6.0"}])

write_to_file = fn type, values ->
  values = Enum.take(values, 100_000_000)

  latencies = Enum.map(values, fn [_, _, lat] -> String.to_float(lat) end)
  mean = Statistics.mean(latencies)
  median = Statistics.mean(latencies)
  perc = Statistics.percentile(latencies, 99)

  IO.puts("STATS for #{type} (#{length(values)} values): mean = #{mean}, median = #{median}, 99th % = #{perc}")

  values
  |> Enum.filter(fn [_type, _ts, latency] -> String.to_float(latency) > 0.5 end)
  |> Enum.map(fn [_type, ts, latency] -> "#{ts} #{latency}" end)
  |> Enum.join("\n")
  |> then(&File.write!("#{type}_log.txt", &1))
end

logs =
  "log.txt"
  |> File.read!()
  |> String.split("\n")
  |> Enum.map(&String.split(&1, " "))
  |> Enum.filter(fn
    [type, _, _] -> type in ["pc", "dtls", "ice"]
    _other -> false
  end)

[_, first_ts, _] = hd(logs)

logs
|> Enum.map(fn
  [type, ts, val] -> [type, String.to_integer(ts) - String.to_integer(first_ts), val]
end)
|> Enum.group_by(fn [type, _, _] -> type end)
|> Enum.map(fn {k, v} ->  write_to_file.(k, v) end)

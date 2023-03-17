list = Enum.shuffle(1..1000) |> Enum.map(&[&1])
dates = Enum.map(list, fn [i] -> [Date.add(~D[2020-01-02], i)] end)
set = MapSet.new(list)

Benchee.run(
  %{
    "Enum (list)" => fn -> Enum.sort_by(list, &hd/1) end,
    "Cmp (list)" => fn -> Cmp.sort_by(list, &hd/1) end,
    "Enum (dates)" => fn -> Enum.sort_by(dates, &hd/1, Date) end,
    "Cmp (dates)" => fn -> Cmp.sort_by(dates, &hd/1) end,
    "Enum (set)" => fn -> Enum.sort_by(set, &hd/1) end,
    "Cmp (set)" => fn -> Cmp.sort_by(set, &hd/1) end,
  },
  time: 2,
  memory_time: 0.5
)

list = Enum.shuffle(1..1000) |> Enum.map(&[&1])
dates = Enum.map(list, fn [i] -> [Date.add(~D[2020-01-02], i)] end)
set = MapSet.new(list)

Benchee.run(
  %{
    "Enum (list)" => fn -> Enum.max_by(list, &hd/1) end,
    "Cmp (list)" => fn -> Cmp.max_by(list, &hd/1) end,
    "Enum (dates)" => fn -> Enum.max_by(dates, &hd/1, Date) end,
    "Cmp (dates)" => fn -> Cmp.max_by(dates, &hd/1) end,
    "Enum (set)" => fn -> Enum.max_by(set, &hd/1) end,
    "Cmp (set)" => fn -> Cmp.max_by(set, &hd/1) end,
  },
  time: 2
)

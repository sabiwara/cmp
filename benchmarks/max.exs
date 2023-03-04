list = Enum.shuffle(1..1000)
dates = Enum.map(list, &Date.add(~D[2020-01-02], &1))
set = MapSet.new(list)

Benchee.run(
  %{
    "Enum (list)" => fn -> Enum.max(list) end,
    "Cmp (list)" => fn -> Cmp.max(list) end,
    "Enum (dates)" => fn -> Enum.max(dates, Date) end,
    "Cmp (dates)" => fn -> Cmp.max(dates) end,
    "Enum (set)" => fn -> Enum.max(set) end,
    "Cmp (set)" => fn -> Cmp.max(set) end,
  },
  time: 2
)

list = Enum.shuffle(1..100)
dates = Enum.map(list, &Date.add(~D[2020-01-02], &1))
set = MapSet.new(list)

Benchee.run(
  %{
    "Enum (list)" => fn -> Enum.sort(list) end,
    "Cmp (list)" => fn -> Cmp.sort(list) end,
    "Enum (dates)" => fn -> Enum.sort(dates, Date) end,
    "Cmp (dates)" => fn -> Cmp.sort(dates) end,
    "Enum (list, desc)" => fn -> Enum.sort(list, :desc) end,
    "Cmp (list, desc)" => fn -> Cmp.sort(list, :desc) end,
    "Enum (set)" => fn -> Enum.sort(set) end,
    "Cmp (set)" => fn -> Cmp.sort(set) end,
  },
  time: 2,
  memory_time: 0.5
)

defmodule ShiftScraper.Code do
  defstruct [:source, :keys, :reward, :date, :status_pc, :status_ps, :status_xb, :code_pc, :code_ps, :code_xb]
end

defmodule ShiftScraper do
  use Timex

  @doc """
  noi?
  """
  def scrape() do
    get_source()
    |> parse_source
    |> filter
    |> pretty_print
  end

  defp filter(results) do
    Enum.filter(results, fn(x) -> x.status_ps == "Works" end)
  end

  defp pretty_print(results) do
    Enum.map(results, fn(x) ->
      IO.puts("#{x.date} \t #{x.code_ps} : #{x.reward}")
    end)
  end

  defp get_source do
    case HTTPoison.get("http://orcz.com/Borderlands_2:_Golden_Key") do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} -> {:ok, body}
      {:ok, %HTTPoison.Response{status_code: 404}} -> {:error, "Not found"}
      {:error, %HTTPoison.Error{reason: reason}} -> {:error, reason}
      _ -> {:error, "unknown"}
    end
  end

  defp parse_source({:ok, body}) do
    Floki.find(body, "table[class~=wikitable] > tr")
    |> Enum.drop(1)
    |> Enum.map(&parse_row(&1))
  end

  defp parse_source({:error, reason}) do
    raise "Failed to retrieve source: #{reason}"
  end

  defp parse_row({_, _, cells}) do
    Enum.map(cells, &Floki.text(&1))
    |> Enum.map(&String.trim(&1))
    |> Enum.with_index
    |> Enum.reduce(%ShiftScraper.Code{}, &assign_cell(&1, &2))
  end

  defp assign_cell(cell, shift_code) do
    case cell do
      {value, 0} ->
        %{shift_code | source: value}
      {value, 1} ->
        parse_reward(value, shift_code)
      {value, 2} ->
        parse_date(value, shift_code)
      {value, 3} ->
        parse_status(value, shift_code)
      {value, 4} ->
        %{shift_code | code_pc: value}
      {value, 5} ->
        %{shift_code | code_ps: value}
      {value, 6} ->
        %{shift_code | code_xb: value}
      _ ->
        shift_code
    end
  end

  defp parse_date(value, shift_code) do
    case Regex.named_captures(~r/(?<m>[a-z]{3})([a-z]+)?\s+(?<d>\d{1,2}),\s(?<y>\d{4})/i, value) do
      %{"y" => y, "m" => m, "d" => d} ->
        %{shift_code | date: Timex.parse!("#{m}-#{d}-#{y}", "{Mshort}-{D}-{YYYY}")}
      _ ->
        shift_code
    end
  end

  defp parse_reward(value, shift_code) do
    value = String.replace(value, "\n", " ")
    key_count = Regex.named_captures(~r/(?<keys>\d+)(.+)?golden key/i, value)
    %{shift_code | reward: value, keys: key_count["keys"]}
  end

  defp parse_status(value, shift_code) do
    status_pc = Regex.named_captures(~r/pc.+:(\s)(?<pc>.+)\s/i, value)["pc"]
    status_ps = Regex.named_captures(~r/play.+:(\s)(?<ps>.+)\s/i, value)["ps"]
    status_xb = Regex.named_captures(~r/xbox:(\s)(?<xb>.+)\s/i, value)["xb"]
    %{shift_code | status_pc: status_pc, status_ps: status_ps, status_xb: status_xb}
  end
end

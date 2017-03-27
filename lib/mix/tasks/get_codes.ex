defmodule Mix.Tasks.GetCodes do
  use Mix.Task

  @shortdoc "Scrape codes"
  def run(_) do
    Mix.Task.run "app.start", []
    ShiftScraper.scrape
  end
end

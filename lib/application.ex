defmodule O2M.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    {:ok, jobs} = generate_jobs()

    children = jobs ++ [O2M]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: O2M.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Generated jobs inside an enum for each podcast to watch
  defp generate_jobs() do
    {:ok, conf} = Application.fetch_env(:o2m, :feed_urls)

    urls = String.split(conf, ",")

    jobs = Enum.map(urls, fn e -> %{id: "jobs-#{e}", start: {Jobs, :start_link, [e]}} end)

    {:ok, jobs}
  end
end

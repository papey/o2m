defmodule O2M.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger
  use DynamicSupervisor

  def start(_type, _args) do
    # DynamicSupervisor setup
    # Children spec
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: O2M.DynamicSupervisor}
    ]

    # Start Supervisor
    Supervisor.start_link(children, strategy: :one_for_one)

    # Start O2M main functions
    DynamicSupervisor.start_child(O2M.DynamicSupervisor, O2M)

    # Add per feed jobs
    case add_jobs() do
      {:ok, urls} ->
        Logger.info("#{length(urls)} job(s) started")

      {:none, message} ->
        Logger.warn(message)
    end

    # Return {:ok, pid}
    {:ok, self()}
  end

  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  # Generated jobs inside an enum for each podcast to watch
  defp add_jobs() do
    Logger.info("Application is starting per feed jobs")

    case(Application.fetch_env(:o2m, :feed_urls)) do
      {:ok, nil} ->
        {:none, "There is no feed URL configured"}

      :error ->
        {:none, "There is no feed URL configured"}

      {:ok, conf} ->
        case String.split(conf, ",") do
          [] ->
            {:none, "There is no URL configured"}

          urls ->
            Enum.map(urls, fn e ->
              Logger.info("Setting up feed job", url: e)

              DynamicSupervisor.start_child(O2M.DynamicSupervisor, %{
                id: "job-#{e}",
                start: {Jobs, :start_link, [e]}
              })
            end)

            {:ok, urls}
        end
    end
  end
end

defmodule O2M.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger
  use DynamicSupervisor
  alias Nostrum.Api
  alias O2M.Config

  def start(_type, _args) do
    # Init the config, fail early
    Config.init!()

    # DynamicSupervisor setup
    # Children spec
    children = [
      O2M,
      {DynamicSupervisor, strategy: :one_for_one, name: O2M.DynamicSupervisor}
    ]

    # Start Supervisor
    {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

    # Custom Username
    Api.Self.modify(username: Config.get(:nickname))
    Api.Guild.modify_self_nick(Config.get(:guild), %{nick: Config.get(:nickname)})

    if Config.get(:feed_urls) != "" do
      {:ok, urls} = start_watchers(Config.get(:feed_urls))
      Logger.info("#{length(urls)} watcher job(s) started")
    else
      Logger.info("No watcher jobs started")
    end

    # start the monitor in the dynamic supervisor
    if Config.get(:bt) do
      Logger.info("Starting game monitor")

      DynamicSupervisor.start_child(
        O2M.DynamicSupervisor,
        %{
          id: Game.Monitor,
          start: {Game.Monitor, :start_link, [Config.get(:bt_chan)]},
          restart: :permanent,
          shutdown: 4000,
          type: :worker
        }
      )

      Logger.info("Starting party agent")

      DynamicSupervisor.start_child(
        O2M.DynamicSupervisor,
        %{
          id: Party,
          start: {Party, :start_link, []},
          restart: :permanent,
          shutdown: 4000,
          type: :worker
        }
      )
    end

    # Return {:ok, pid}
    {:ok, self()}
  end

  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  # Generated jobs inside an enum for each podcast to watch
  defp start_watchers(urls) do
    case String.split(urls, " ") do
      [] ->
        {:ok, []}

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

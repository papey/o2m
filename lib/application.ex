defmodule O2M.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger
  use DynamicSupervisor
  alias Nostrum.Api

  def start(_type, _args) do
    # DynamicSupervisor setup
    # Children spec
    children = [
      O2M,
      {DynamicSupervisor, strategy: :one_for_one, name: O2M.DynamicSupervisor}
    ]

    # Start Supervisor
    {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

    nickname = Application.fetch_env!(:o2m, :nickname)
    gid = from_env_to_int(:o2m, :guild)

    # Custom Username
    Api.modify_current_user(username: nickname)
    Api.modify_current_user_nick!(gid, %{nick: nickname})

    # Add per feed jobs
    case add_jobs() do
      {:ok, urls} ->
        Logger.info("#{length(urls)} job(s) started")

      {:none, message} ->
        Logger.warn(message)
    end

    # start the monitor in the dynamic supervisor
    if BlindTest.configured?() do
      Logger.info("Starting game monitor")

      DynamicSupervisor.start_child(
        O2M.DynamicSupervisor,
        %{
          id: Game.Monitor,
          start: {Game.Monitor, :start_link, [from_env_to_int(:o2m, :bt_chan)]},
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

  def from_env_to_int(app, val) do
    {ret, ""} = Integer.parse(Application.fetch_env!(app, val))
    ret
  end

  # Generated jobs inside an enum for each podcast to watch
  defp add_jobs() do
    Logger.info("Application is starting per feed jobs")

    case Application.fetch_env(:o2m, :feed_urls) do
      n when n in [{:ok, nil}, :error] ->
        {:none, "There is no feed URL configured"}

      {:ok, conf} ->
        case String.split(conf, " ") do
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

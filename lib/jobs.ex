defmodule Jobs do
  @moduledoc """
  A module used to schedule jobs
  """
  use GenServer
  require Logger
  alias Nostrum.Api

  ## GenServer API
  @doc """
  Starts the GenServer
  """
  def start_link(init) do
    Logger.info("Starting job link", init: init)
    GenServer.start_link(__MODULE__, init)
  end

  @doc """
  Init GenServer state
  """
  def init(init) do
    Logger.info("Init job link", init: init)
    last = Feed.get_last_episode(init)
    state = {init, last}
    {:ok, state, {:continue, :work}}
  end

  @doc """
  Init the scheduled loop
  """
  def handle_continue(:work, state) do
    {url, _} = state
    Logger.info("Continue received", url: url)
    {:noreply, work_then_reschedule(state)}
  end

  @doc """
  handle loop event and reloop
  """
  def handle_info(:work, state) do
    {url, _} = state
    Logger.info("Info received", url: url)
    {:noreply, work_then_reschedule(state)}
  end

  @doc """
  Get timer config from `config.exs` file

  Returns timer configuration
  """
  def get_timer_config() do
    from_env_to_int(:o2m, :timer)
  end

  defp work_then_reschedule(state) do
    # Fetch current state
    {url, cur} = state

    # Get last episode from feed
    new = Feed.get_last_episode(url)

    # Wait
    Process.send_after(self(), :work, get_timer_config() * 1000)

    # Is the last episode fetch a new one ?
    case Feed.compare_dates(cur.date, new.date) do
      # If so
      -1 ->
        # Post a message
        Api.create_message(from_env_to_int(:o2m, :chan), Feed.new_message(new))
        # Update state
        Logger.info("Updating state", url: url)
        {url, new}

      _ ->
        # Keep old state
        Logger.info("Keeping the old state", url: url)
        state
    end
  end

  defp from_env_to_int(app, val) do
    {:ok, v} = Application.fetch_env(app, val)
    {ret, ""} = Integer.parse(v)
    ret
  end
end

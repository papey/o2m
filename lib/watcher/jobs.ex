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
    {:noreply, state, {:continue, :work}}
  end

  @doc """
  Get timer config from `config.exs` file

  Returns timer configuration
  """
  def get_timer_config() do
    O2M.Application.from_env_to_int(:o2m, :timer)
  end

  defp work_then_reschedule(state) do
    # Fetch current state
    {url, last} = state

    # Wait
    Process.send_after(self(), :work, get_timer_config() * 1000)

    # Get last episode from feed
    case Feed.get_last_episode(url) do
      # If no data from new episode, return the old state
      :nodata ->
        state

      # If there is fresh data
      new ->
        # if no data, consider it as an init
        case last do
          :nodata ->
            Logger.info("Setting up state after receiving no data", url: url)
            {url, new}

          # Pattern match the old date
          %{:date => date, :show => _, :title => _, :url => _} ->
            case Feed.compare_dates(date, new.date) do
              # If so
              -1 ->
                # Post a message
                Api.create_message(
                  O2M.Application.from_env_to_int(:o2m, :chan),
                  Feed.new_message(new)
                )

                # Update state
                Logger.info("Updating state", url: url)
                {url, new}

              _ ->
                # Keep old state
                Logger.info("Keeping the old state", url: url)
                state
            end
        end
    end
  end
end

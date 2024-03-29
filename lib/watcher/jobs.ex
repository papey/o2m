defmodule Jobs do
  @moduledoc """
  A module used to schedule jobs
  """
  use GenServer
  require Logger
  alias Nostrum.Api
  alias O2M.Config

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

  defp work_then_reschedule({url, state}) do
    # Wait
    Process.send_after(self(), :work, Config.get(:jobs_timer) * 1000)

    # Get last episode from feed
    next =
      url
      |> Feed.get_last_episode()
      |> refresh_state(state)

    {url, next}
  end

  defp refresh_state(:nodata, old), do: old

  defp refresh_state(new, :nodata), do: new

  defp refresh_state(new, old) do
    if Timex.compare(old.date, new.date) == -1 do
      # Post a message
      Api.create_message(
        Config.get(:chan),
        Feed.new_message(new)
      )

      # Update state
      Logger.info("Updating state", url: new.url)
      new
    else
      # Keep old state
      Logger.info("Keeping the old state", url: old.url)
      old
    end
  end
end

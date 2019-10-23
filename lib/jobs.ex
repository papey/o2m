defmodule Jobs do
  @moduledoc """
  A module used to schedule jobs
  """
  use GenServer
  alias Nostrum.Api

  ## GenServer API
  # Start link
  def start_link([]) do
    GenServer.start_link(__MODULE__, [])
  end

  # Init
  @spec init(any) ::
          {:ok, {binary, %{date: any, show: any, title: any, url: any}}, {:continue, :work}}
  def init(_init) do
    {:ok, slug} = Application.fetch_env(:o2m, :ausha_slug)
    last = Ausha.get_last_episode(slug)
    state = {slug, last}
    {:ok, state, {:continue, :work}}
  end

  # First run
  @spec handle_continue(:work, {binary, atom | %{date: binary}}) ::
          {:noreply, {binary, atom | %{date: binary}}}
  def handle_continue(:work, state) do
    {:noreply, work_then_reschedule(state)}
  end

  # When an info message is received
  @spec handle_info(:work, {binary, atom | %{date: binary}}) ::
          {:noreply, {binary, atom | %{date: binary}}}
  def handle_info(:work, state) do
    {:noreply, work_then_reschedule(state)}
  end

  @doc """
  Get timer config from `config.exs` file

  Returns timer configuration
  """
  @spec get_timer_config :: any
  def get_timer_config() do
    {:ok, timer} = Application.fetch_env(:o2m, :timer)
    timer
  end

  defp work_then_reschedule(state) do
    # Fetch current state
    {slug, cur} = state

    # Get last episode from Ausha
    new = Ausha.get_last_episode(slug)

    # Wait
    Process.send_after(self(), :work, get_timer_config() * 1000)

    # Is the last episode fetch a new one ?
    case Ausha.compare_dates(cur.date, new.date) do
      # If so
      true ->
        # Post a message
        Api.create_message(Application.fetch_env!(:o2m, :chan), Ausha.new_message(new))
        # Update state
        {slug, new}

      false ->
        # Keep old state
        state
    end
  end
end

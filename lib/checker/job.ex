defmodule Checker.Job do
  @moduledoc false

  use GenServer

  alias Checker.{Util, Job}
  require Logger

  defstruct [:instance, :url, :interval, :caller]

  def start_link(args) do
    instance = Keyword.fetch!(args, :instance)
    url = Keyword.fetch!(args, :url)
    via = Util.via({:job, instance, url})

    GenServer.start_link(__MODULE__, args, name: via)
  end

  @impl GenServer
  def init(job_args) do
    # Process.flag(:trap_exit, true)

    caller = Keyword.fetch!(job_args, :caller)
    interval = Keyword.fetch!(job_args, :interval)
    url = Keyword.fetch!(job_args, :url)
    job = %Job{caller: caller, interval: interval, url: url}

    {:ok, job, {:continue, :launch}}
  end

  @impl GenServer
  def handle_continue(:launch, job) do
    Process.send(self(), :check_status, [])
    {:noreply, job}
  end

  @impl GenServer
  def handle_info(
        :check_status,
        %Job{interval: interval, caller: caller, url: url} = job
      ) do
    _task = fetch_url_and_update_status(url, caller)
    Process.send_after(self(), :check_status, interval)

    {:noreply, job}
  end

  def handle_info({:error_status, error}, %{url: url, caller: caller} = job) do
    Logger.warn("URL returned an error status. Error: #{inspect(error)}; Job: #{inspect(job)}")
    Process.send(caller, {:update_status, url, :error}, [])
    {:stop, :shutdown, job}
  end

  @impl GenServer
  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  @impl GenServer
  def terminate(:shutdown, _state) do
    :normal
  end

  ##############################
  # Helpers

  defp url_util() do
    Application.get_env(:checker, :url_util)
  end

  defp fetch_url_and_update_status(url, caller) do
    pid = self()

    Task.start(fn ->
      case url_util().fetch_url_status(url) do
        {:ok, updated_status} ->
          Process.send(caller, {:update_status, url, updated_status}, [])
          updated_status

        {:error, exception} ->
          Process.send(pid, {:error_status, exception}, [])
          :error
      end
    end)
  end
end

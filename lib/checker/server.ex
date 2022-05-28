defmodule Checker.Server do
  @moduledoc false

  use GenServer
  use GenServerSync

  alias Checker.Util
  require Logger
  import Checker, only: [is_status: 1, is_instance: 1]

  def start_link(args) do
    instance = Keyword.fetch!(args, :instance)
    interval = Keyword.get(args, :interval, Checker.__default_interval__())

    config = %{
      instance: instance,
      interval: interval
    }

    via = Util.via({:server, instance}, config)
    GenServer.start_link(__MODULE__, args, name: via)
  end

  @impl GenServer
  def init(_args \\ []) do
    Process.flag(:trap_exit, true)
    {:ok, %{}}
  end

  @impl GenServer
  def handle_info({:update_status, url, new_status}, state) do
    Logger.debug("{{#{new_status}}} #{url}")
    new_state = update_status(state, url, new_status)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:add, url}, state) when is_map_key(state, url) do
    {:noreply, state}
  end

  def handle_cast({:add, url}, state) do
    {:ok, _supervisor_job_pid} =
      with pid <- self(),
           instance <- Util.get_instance(pid),
           interval <- Util.get_config!(pid, :interval) do
        start_job(instance,
          url: url,
          interval: interval,
          caller: self()
        )
      end

    new_state = Map.put_new(state, url, nil)

    {:noreply, new_state}
  end

  def handle_cast({:delete, url}, state) do
    instance = Util.get_instance(self())

    case Map.pop(state, url, :key_not_found) do
      {:key_not_found, _state} ->
        {:noreply, state}

      {:error, new_state} ->
        {:noreply, new_state}

      {_status, new_state} ->
        :ok =
          with via_job_supervisor <- Util.via({:job_supervisor, instance}),
               :ok <- Supervisor.terminate_child(via_job_supervisor, {:job, instance, url}) do
            Supervisor.delete_child(via_job_supervisor, {:job, instance, url})
          end

        {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_call(:list, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:list, status}, _from, state) when is_status(status) do
    results =
      Enum.reduce(state, [], fn
        {url, ^status}, acc ->
          [url | acc]

        _, acc ->
          acc
      end)
      |> Enum.sort()

    {:reply, results, state}
  end

  def handle_call(:reset, _from, _state) do
    {:ok, _pid} =
      with pid <- self(),
           instance <- Util.get_instance(pid),
           via_instance <- Util.via(instance),
           :ok <- Supervisor.terminate_child(via_instance, Checker.JobSupervisor) do
        Supervisor.restart_child(via_instance, Checker.JobSupervisor)
      end

    {:reply, %{}, %{}}
  end

  # For helpers
  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:config, _from, state) do
    pid = self()
    {:reply, Util.get_config(pid), state}
  end

  def handle_call({:status, url}, _from, state) when is_binary(url) do
    status = Map.get(state, url, :error)

    {:reply, status, state}
  end

  def handle_call({:job_pid, url}, _from, state) do
    instance = Util.get_instance(self())
    {:reply, Util.get_job_pid(instance, url), state}
  end

  def handle_call(:supervisor_pid, _from, state) do
    supervisor_pid =
      self()
      |> Util.get_config!(:supervisor_name)
      |> Util.pid()

    {:reply, supervisor_pid, state}
  end

  def handle_call(:pid, _from, state) do
    {:reply, self(), state}
  end

  @impl GenServer
  def terminate(_reason, _state) do
    :shutdown
  end

  ##############################
  # Helpers

  @doc false
  def start_job(instance, args) when is_instance(instance) and is_list(args) do
    Util.require_keys!(args, [:url, :interval, :caller])

    url = Keyword.fetch!(args, :url)
    via_job = Util.via({:job, instance, url})
    via_job_supervisor = Util.via({:job_supervisor, instance})

    args =
      args
      |> Keyword.put(:instance, instance)
      |> Keyword.put(:shutdown, 1)

    child_spec = %{
      id: {:job, instance, url},
      start: {Checker.Job, :start_link, [args ++ [name: via_job]]},
      restart: :transient
    }

    {:ok, _pid} = Supervisor.start_child(via_job_supervisor, child_spec)
  end

  defp update_status(state, url, new_status) when is_binary(url) and is_status(new_status) do
    Map.replace(state, url, new_status)
  end
end

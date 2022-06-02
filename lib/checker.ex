defmodule Checker do
  @moduledoc """
  App that checks the status of given URLs.
  """

  alias Checker.Util

  @default_inverval 3000

  @type instance :: atom() | String.t()
  @type url :: String.t()
  @type status :: http_response_status | :unreachable | nil | :error
  @type http_response_status :: 100..599

  defguard is_http_response_status(term) when term in 100..599

  defguard is_status(term)
           when is_http_response_status(term) or term in [:unreachable, nil, :error]

  defguard is_instance(term) when is_atom(term) or is_binary(term)

  def __default_interval__() do
    @default_inverval
  end

  @spec start(instance, keyword) :: DynamicSupervisor.on_start_child()
  def start(instance, args \\ []) when is_instance(instance) and is_list(args) do
    args = Keyword.put(args, :instance, instance)

    instance_child_spec = {Checker.Instance, args ++ [strategy: :one_for_one]}

    {:ok, _instance_pid} =
      DynamicSupervisor.start_child(Checker.ServerSupervisor, instance_child_spec)
  end

  @spec stop(instance) :: :ok | {:error, :not_found}
  def stop(instance) when is_instance(instance) do
    case Util.pid(instance) do
      pid when is_pid(pid) ->
        via_instance = Util.via(instance)
        DynamicSupervisor.stop(via_instance, :shutdown)

      nil ->
        {:error, :not_found}
    end
  end

  @spec list(instance) :: %{url => status}
  def list(instance) when is_instance(instance) do
    via_server = Util.via({:server, instance})
    GenServer.call(via_server, :list)
  end

  @spec list(instance, status) :: [url]
  def list(instance, status) when is_instance(instance) and is_status(status) do
    via_server = Util.via({:server, instance})
    GenServer.call(via_server, {:list, status})
  end

  @spec add(instance, url) :: :ok
  def add(instance, url) when is_instance(instance) and is_binary(url) do
    via_server = Util.via({:server, instance})
    GenServer.cast(via_server, {:add, url})
  end

  @spec delete(instance, url) :: :ok
  def delete(instance, url) when is_instance(instance) and is_binary(url) do
    via_server = Util.via({:server, instance})
    GenServer.cast(via_server, {:delete, url})
  end

  @spec reset(instance) :: %{}
  def reset(instance) when is_instance(instance) do
    via_server = Util.via({:server, instance})
    GenServer.call(via_server, :reset)
  end

  @spec status(instance, url) :: status
  def status(instance, url) when is_instance(instance) and is_binary(url) do
    via_server = Util.via({:server, instance})
    GenServer.call(via_server, {:status, url})
  end

  @spec job_pid(instance, url) :: pid | nil

  def job_pid(instance, url) when is_instance(instance) and is_binary(url) do
    via_server = Util.via({:server, instance})
    GenServer.call(via_server, {:job_pid, url})
  end

  ##################
  # Helpers

  @doc false
  @spec state(instance) :: term()
  def state(instance) when is_instance(instance) do
    via_server = Util.via({:server, instance})
    GenServer.call(via_server, :state)
  end

  @doc false
  @spec config(instance) :: map()
  def config(instance) when is_instance(instance) do
    via_server = Util.via({:server, instance})
    GenServer.call(via_server, :config)
  end

  @doc false
  @spec debug(level :: :all | :none | Logger.level()) :: :ok
  def debug(level)

  def debug(:none) do
    Logger.remove_backend(:console)
    :ok
  end

  def debug(:all) do
    Logger.add_backend(:console)
    Logger.configure(level: :debug)
  end

  @levels [:emergency, :alert, :critical, :error, :warning, :warn, :notice, :info, :debug]
  def debug(level) when is_atom(level) and level in @levels do
    Logger.add_backend(:console)
    Logger.configure(level: level)
  end
end

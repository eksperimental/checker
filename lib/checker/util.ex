defmodule Checker.Util do
  @moduledoc false

  use Gradient.TypeAnnotation
  import Checker, only: :macros

  @spec fetch_url_status(Checker.url()) ::
          {:ok, Checker.http_response_status() | :unreachable} | {:error, Exception.t()}
  def fetch_url_status(url) when is_binary(url) do
    try do
      Req.request(:get, url, receive_timeout: 3000)
    rescue
      error ->
        {:error, error}
    else
      {:ok, response} ->
        {:ok, response.status}

      {:error, _error} ->
        {:ok, :unreachable}
    end
  end

  @spec via(key) :: {:via, module, {module, key}} when key: term
  def via(key) do
    {:via, Registry, {Checker.Registry, key}}
  end

  @spec via(key, value) :: {:via, module, {module, key, value}} when key: term, value: term
  def via(key, value) do
    {:via, Registry, {Checker.Registry, key, value}}
  end

  @spec unique_id() :: pos_integer()
  def unique_id() do
    System.unique_integer([:positive, :monotonic])
    |> assert_type({:pos_integer, 0})
  end

  @spec pid(term) :: pid | nil
  def pid(term) when is_pid(term),
    do: term

  def pid(term) do
    case Registry.lookup(Checker.Registry, term) do
      [{pid, _}] ->
        pid

      [] ->
        nil
    end
  end

  @spec child_pid(pid) :: pid
  def child_pid(pid) when is_pid(pid) do
    children =
      pid
      |> Supervisor.which_children()
      |> Enum.reject(fn
        {{:job, _pid, _url}, _child_pid, _type, _modules} ->
          true

        _ ->
          false
      end)

    case children do
      [{_id, child_pid, _type, _modules}] when is_pid(child_pid) ->
        child_pid
    end
  end

  def require_keys!(keyword_list, keys) when is_list(keyword_list) when is_list(keys) do
    for key <- keys do
      require_key!(keyword_list, key)
    end
  end

  def require_keys!(keyword_list, key) when is_list(keyword_list) when is_atom(key) do
    require_key!(keyword_list, key)
  end

  @compile {:inline, require_key!: 2}
  defp require_key!(keyword_list, key) do
    Keyword.fetch!(keyword_list, key)
  end

  # Registry
  @doc false
  def get_job_pid(instance, url) when is_instance(instance) and is_binary(url) do
    case Registry.lookup(Checker.Registry, {:job, instance, url}) do
      [{job_pid, _}] ->
        job_pid

      [] ->
        nil
    end
  end

  def get_instance(pid) do
    case get_registry_key(pid) do
      {:server, key} ->
        key

      {:job, key} ->
        key

      {:job_supervisor, key} ->
        key
    end
  end

  defp get_registry_key(pid) when is_pid(pid) do
    [result] = Registry.keys(Checker.Registry, pid)
    result
  end

  def get_config(pid) do
    key = get_registry_key(pid)
    [{_pid, config}] = Registry.lookup(Checker.Registry, key)
    config
  end

  def get_config!(pid, key) do
    pid
    |> get_config()
    |> Map.fetch!(key)
  end
end

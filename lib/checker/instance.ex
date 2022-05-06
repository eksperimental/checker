defmodule Checker.Instance do
  @moduledoc false

  alias Checker.Util

  # Automatically defines child_spec/1
  use Supervisor, restart: :transient

  def start_link(args) do
    instance = Keyword.fetch!(args, :instance)

    args =
      args
      |> Keyword.put_new(:interval, Checker.__default_interval__())

    config = %{
      instance: instance,
      interval: Keyword.fetch!(args, :interval)
    }

    Supervisor.start_link(__MODULE__, args, name: Util.via(instance, config))
  end

  @impl true
  def init(args) do
    children = [
      {Checker.Server, args},
      {Checker.JobSupervisor, args}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

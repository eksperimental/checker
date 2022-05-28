defmodule Checker.JobSupervisor do
  @moduledoc false

  use Supervisor, restart: :transient

  alias Checker.Util

  def start_link(args) do
    instance = Keyword.fetch!(args, :instance)

    Supervisor.start_link(__MODULE__, args, name: Util.via({:job_supervisor, instance}))
  end

  @impl Supervisor
  def init(_args) do
    # Process.flag(:trap_exit, true)

    options = [
      strategy: :one_for_one
    ]

    children = []
    Supervisor.init(children, options)
  end
end

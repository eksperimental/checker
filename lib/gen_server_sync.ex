defmodule GenServerSync do
  @moduledoc """
  Synchronous asserts on GenServer cast calls.

  Examples:

      defmodule Foo  do
        # Public API
        def add(server_pid, element) do
          GenServer.cast(server_pid, element)
        end
      end

      defmodule Foo.Server do
        use GenServer

        # use GenServerSync after `use GenServer`
        use GenServerSync

        @impl GenServer
        def init(_args) do
          {:ok, []}
        end

        @impl GenServer
        def handle_cast({:add, element}, state) do
          {:reply, state ++ [element]}
        end

        @impl GenServer
        def handle_info({:delete, element}, state) do
          {:reply, state -- [element]}
        end
      end

      defmodule Foo.ServerTest do
        use ExUnit.Case, async: true

        # import all functions
        import GenServerSync

        test "assert on a GenServer.cast/2 call" do
          ...

          assert await_cast(server_pid, {:add, [3]}) == [1, 2, 3]

          Foo.add(4)
          state = await(server_pid)
          assert state == [1, 2, 3, 4]
        end
      end

  """

  require Logger

  @type server :: GenServer.name()
  @type from_pid :: pid() | nil

  defmacro __using__(_options \\ []) do
    quote generated: true do
      if Mix.env() == :test do
        def handle_call({unquote(__MODULE__), :__state__}, from_pid, state) do
          {:reply, state, state}
        end
      end
    end
  end

  @doc """
  Awaits on an syncronous GenServer call.any()

  It could be a cast or a message passed the GenServer.
  """
  @spec await(server(), from_pid(), options) :: state when state: term(), options: keyword()
  def await(server, from_pid \\ nil, options \\ []) when is_pid(from_pid) or is_nil(from_pid) do
    log_time? = Keyword.get(options, :log_time, true)

    response = GenServer.call(server, {__MODULE__, :__state__}, :infinity)

    if log_time? do
      init_time = :os.system_time(:millisecond)
      log_time(init_time)
    end

    response
  end

  #######################################
  # Helpers

  defp log_time(init_time) do
    elapased_time =
      (:os.system_time(:millisecond) - init_time)
      |> to_string()
      |> Code.format_string!()

    Logger.debug("Arrived in #{elapased_time}ms.")
  end
end

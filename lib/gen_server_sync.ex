defmodule GenServer.Sync.Case do
  @moduledoc false

  defmacro __using__(_options \\ []) do
    quote generated: true do
      require Logger
      import GenServer.Sync, only: [cast: 2]
    end
  end
end

defmodule GenServer.Sync do
  @moduledoc """
  Synchronous asserts on GenServer cast calls.

  Examples:

      defmodule Foo.Server do
        use GenServer

        # use GenServer.Sync after `use GenServer`
        use GenServer.Sync

        @impl GenServer
        def init(_args \\ []) do
          {:ok, %{}}
        end

        ...
      end

      defmodule FooTest do
        use ExUnit.Case, async: true

        use GenServer.Sync.Case

        test "assert on a GenServer.cast/2 call" do
          assert cast(pid, {:my_request, :foo, :bar}) == [1, 2, 3]
        end
      end

  """

  defmacro __using__(_options \\ []) do
    quote generated: true do
      if Mix.env() == :test do
        def handle_cast({:__debug_state__, from_pid, time}, state) do
          Process.send(from_pid, {:__debug__, state, time}, [])

          {:noreply, state}
        end
      end
    end
  end

  defmacro cast(server, request, from_pid \\ nil) do
    quote do
      GenServer.cast(unquote(server), unquote(request))

      from_pid = unquote(from_pid) || self()
      init_time = :os.system_time(:millisecond)
      GenServer.cast(unquote(server), {:__debug_state__, from_pid, init_time})

      receive do
        {:__debug__, state, init_time} ->
          elapased_time =
            (:os.system_time(:millisecond) - init_time)
            |> to_string()
            |> Code.format_string!()

          Logger.debug("Arrived in #{elapased_time}ms.")

          state
      end
    end
  end
end

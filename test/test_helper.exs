ExUnit.start()

defmodule TestHelper do
  @default_sleep_timeout 1500
  def sleep(timeout \\ @default_sleep_timeout) when is_integer(timeout) and timeout >= 0 do
    Process.sleep(timeout)
  end

  defmacro id() do
    quote do
      :"#{__ENV__.file}:#{__ENV__.line}"
    end
  end
end

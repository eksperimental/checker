defmodule Checker.Mock do
  @moduledoc false

  @timeout 10..50

  @live_urls ~W[
    https://github.com
    http://github.com
    https://www.google.com
    http://www.google.com
    https://.google.com
    http://.google.com
  ]

  @spec fetch_url_status(Checker.url()) ::
          {:ok, Checker.http_response_status() | :unreachable} | {:error, Exception.t()}
  @doc """
  Mocks `Checker.Util.fetch_url_status/1` for testing purposes.any()

  It retuns status for URLs such as:
    - "https://up"
    - "https://unreachable"
    - "https://200"
    - "https://404"

  It supports http and https schemes.

  If the url does not match the redefined rules, it calls `Checker.Util.fetch_url_status/1`.
  """
  def fetch_url_status("http://up") do
    sleep()
    {:ok, 200}
  end

  def fetch_url_status("https://up") do
    sleep()
    {:ok, 200}
  end

  def fetch_url_status("http://unreachable") do
    sleep()
    {:ok, :unreachable}
  end

  def fetch_url_status("https://unreachable") do
    sleep()
    {:ok, :unreachable}
  end

  def fetch_url_status(url) when url in ["http://unstable", "https://unstable"] do
    # :rand.seed(:exsss, {100, 101, 102})
    # Enum.random([200, :unreachable])

    # I need to do this, because `Enum.random([200, :unreachable])`,
    # I don't know why.... It is giving always the same result
    result = Enum.random(1..100_000) |> Integer.mod(2)
    random = Enum.at([200, :unreachable], result)
    sleep()

    {:ok, random}
  end

  status_urls =
    for status <- 100..599, scheme <- ["http", "https"] do
      {status, scheme <> "://" <> to_string(status)}
    end

  for {status, url} <- status_urls do
    def fetch_url_status(unquote(url)) do
      sleep()
      {:ok, unquote(status)}
    end
  end

  def fetch_url_status(url) do
    if url in @live_urls and boolify(System.get_env("MOCK_LIVE")) do
      sleep()
      {:ok, 200}
    else
      Checker.Util.fetch_url_status(url)
    end
  end

  #######################
  # Helpers

  defp sleep(), do: @timeout |> Enum.random() |> Process.sleep()

  defp boolify(string) when string in ["false", ""], do: false
  defp boolify(_string), do: true
end

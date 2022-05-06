defmodule CheckerProcessTest do
  import TestHelper

  use ExUnit.Case, async: false

  alias Checker.Util
  import Checker, only: [is_instance: 1]

  @default_interval Checker.__default_interval__()

  @url_github "https://github.com"
  @url_google "https://www.google.com"
  # Mocking URLs
  # @url_up "https://up"
  # @url_unreachable "https://unreachable"
  @url_unstable "https://unstable"
  # @url_malformed "xyz://foo/bar"

  setup do
    instance = Util.unique_id() |> to_string()
    {:ok, pid} = Checker.start(instance, interval: @default_interval)

    on_exit(fn ->
      Checker.stop(instance)

      :ok
    end)

    %{
      instance: instance,
      pid: pid,
      worker_pid: Util.pid({:server, instance})
    }
  end

  describe "add" do
    test "add, remove, add", %{instance: instance} do
      assert Checker.add(instance, @url_github) == :ok
      sleep(5)
      job_pid = Checker.job_pid(instance, @url_github)

      assert Process.alive?(job_pid)

      # DELETE URL
      assert Checker.delete(instance, @url_github) == :ok
      sleep(5)

      refute Process.alive?(job_pid)
      assert Checker.job_pid(instance, @url_github) == nil

      assert Checker.add(instance, @url_github) == :ok
      sleep(5)
      new_job_pid = Checker.job_pid(instance, @url_github)

      assert job_pid != new_job_pid
    end

    test "add existing url does not kill the server", %{
      instance: instance,
      pid: pid,
      worker_pid: worker_pid
    } do
      assert Checker.add(instance, @url_github) == :ok
      assert Checker.add(instance, @url_github) == :ok
      assert Checker.add(instance, @url_github) == :ok

      assert Process.alive?(pid)
      assert Process.alive?(worker_pid)
    end
  end

  describe "servers" do
    test "servers and supervisors are killed", %{
      test: test_name
    } do
      # Start a 1st server
      name1 = test_name
      {:ok, pid1} = Checker.start(name1)
      worker_pid1 = Util.pid({:server, name1})

      assert Checker.add(name1, @url_github) == :ok
      assert Checker.add(name1, @url_google) == :ok
      assert Checker.add(name1, @url_unstable) == :ok

      sleep(100)

      # Job PIDs
      github_pid1 = Checker.job_pid(name1, @url_github)
      google_pid1 = Checker.job_pid(name1, @url_google)
      unstable_pid1 = Checker.job_pid(name1, @url_unstable)

      job_pids1 = [
        github_pid1: github_pid1,
        google_pid1: google_pid1,
        unstable_pid1: unstable_pid1
      ]

      for {k, v} <- job_pids1 do
        assert Process.alive?(v), "#{inspect({k, v})} is not alive"
      end

      Checker.reset(name1)

      for {k, v} <- job_pids1 do
        refute Process.alive?(v), "#{inspect({k, v})} is alive"
      end

      ##################################################
      # Start a 2nd server
      name2 = :"#{test_name}+2"
      {:ok, pid2} = Checker.start(name2)

      # Add again to 1st server
      assert Checker.add(name1, @url_github) == :ok
      assert Checker.add(name1, @url_google) == :ok
      sleep(10)
      github_pid1 = Checker.job_pid(name1, @url_github)
      assert Process.alive?(github_pid1)
      google_pid1 = Checker.job_pid(name1, @url_google)

      job_pids1 = [
        github_pid: github_pid1,
        google_pid: google_pid1
      ]

      # Add again to 2nd server
      assert Checker.add(name2, @url_github) == :ok
      assert Checker.add(name2, @url_google) == :ok
      sleep(10)
      github_pid2 = Checker.job_pid(name2, @url_github)
      google_pid2 = Checker.job_pid(name2, @url_google)

      job_pids2 = [
        github_pid2: github_pid2,
        google_pid2: google_pid2
      ]

      for {k, v} <- job_pids1 ++ job_pids2 do
        assert Process.alive?(v), "#{inspect({k, v})} is not alive"
      end

      assert Process.alive?(pid1)
      assert Process.alive?(worker_pid1)

      Checker.stop(name1)

      refute Process.alive?(pid1)
      refute Process.alive?(worker_pid1)

      for {k, v} <- job_pids1 do
        refute Process.alive?(v), "#{inspect({k, v})} is alive"
      end

      for {k, v} <- job_pids2 do
        assert Process.alive?(v), "#{inspect({k, v})} is not alive"
      end

      assert Process.alive?(pid2)

      worker_pid2 = Util.pid({:server, name2})
      assert Process.alive?(worker_pid2)

      Checker.stop(name2)
    end
  end

  def job_state(instance, url) when is_instance(instance) and is_binary(url) do
    worker_pid = Util.pid({:server, instance})
    GenServer.call(worker_pid, :state)
  end
end

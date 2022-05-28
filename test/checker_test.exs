defmodule CheckerTest do
  alias Checker.Util

  import TestHelper
  import Checker, only: [is_instance: 1]

  use ExUnit.Case, async: false
  use GenServer.Sync.Case

  doctest Checker

  @default_interval Checker.__default_interval__()

  @url_github "https://github.com"
  @url_google "https://www.google.com"
  # Mocking URLs
  @url_up "https://up"
  @url_unreachable "https://unreachable"
  @url_unstable "https://unstable"
  @url_malformed "xyz://foo/bar"

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

  describe "start and stop" do
    test "stop" do
      instance = id()

      {:ok, pid} = Checker.start(instance)
      child_pid = Util.pid({:server, instance})
      :ok = Checker.stop(instance)
      sleep(50)
      refute Process.alive?(pid)
      refute Process.alive?(child_pid)
    end

    test "start/0" do
      instance = id()

      {:ok, pid} = Checker.start(instance)
      child_pid = Util.pid({:server, instance})

      assert is_pid(pid)
      assert is_pid(child_pid)

      Checker.stop(instance)
    end

    test "start/1", %{pid: pid, worker_pid: worker_pid} do
      assert is_pid(pid)
      assert is_pid(worker_pid)
    end

    test "start/2 :job", %{pid: pid, worker_pid: worker_pid, instance: instance} do
      Checker.add(instance, @url_github)
      job_pid = Checker.job_pid(instance, @url_github)

      assert is_pid(pid)
      assert is_pid(worker_pid)
      assert is_pid(job_pid)
    end
  end

  test "default", %{instance: instance} do
    assert Checker.state(instance) == %{}

    assert (%{
              instance: instance,
              interval: @default_interval
            }
            when is_instance(instance)) = Checker.config(instance)
  end

  test "with interval", %{test: test_name} do
    {:ok, _pid} = Checker.start(test_name, interval: 5000)

    assert %{interval: 5000, instance: test_name} = Checker.config(test_name)
    assert Checker.state(test_name) == %{}

    Checker.stop(test_name)
  end

  test "list/1", %{instance: instance} do
    assert Checker.list(instance) == %{}

    Checker.add(instance, @url_github)

    assert Checker.list(instance) == %{
             @url_github => nil
           }

    Checker.add(instance, @url_google)

    assert %{
             @url_github => _,
             @url_google => _
           } = Checker.list(instance)
  end

  test "list/2", %{instance: instance} do
    assert Checker.list(instance, 200) == []
    assert Checker.list(instance, :unreachable) == []

    Checker.add(instance, @url_up)
    Checker.add(instance, @url_unreachable)
    sleep(100)

    assert Checker.list(instance, 200) == [@url_up]
    assert Checker.list(instance, :unreachable) == [@url_unreachable]

    Checker.add(instance, @url_github)
    assert Checker.list(instance, nil) == [@url_github]

    Checker.add(instance, @url_google)
    sleep(2000)

    assert Checker.list(instance, 200) == [
             @url_github,
             @url_up,
             @url_google
           ]
  end

  test "add/2", %{instance: instance} do
    for n <- 1..100 do
      url = "https://#{n}.google.com"
      Checker.add(instance, url)
      url
    end

    assert Checker.list(instance) |> Enum.count() == 100
  end

  test "unreachable urls", %{instance: instance, worker_pid: _worker_pid} do
    assert Checker.add(instance, @url_github) == :ok
    assert Checker.add(instance, "https://this_site_does_not_exist_444445.org") == :ok

    assert %{
             @url_github => _,
             "https://this_site_does_not_exist_444445.org" => _
           } = Checker.list(instance)

    sleep(1000)

    assert Checker.list(instance) == %{
             @url_github => 200,
             "https://this_site_does_not_exist_444445.org" => :unreachable
           }

    assert Checker.state(instance) == %{
             @url_github => 200,
             "https://this_site_does_not_exist_444445.org" => :unreachable
           }

    assert Checker.delete(instance, @url_github) == :ok

    sleep(5)

    assert Checker.list(instance) == %{
             "https://this_site_does_not_exist_444445.org" => :unreachable
           }

    Checker.add(instance, @url_up)
    Checker.add(instance, @url_unreachable)

    assert %{
             "https://this_site_does_not_exist_444445.org" => :unreachable,
             @url_up => _,
             @url_unreachable => _
           } = Checker.list(instance)

    assert Checker.status(instance, @url_up) in [200, nil]

    assert Checker.status(instance, "https://this_site_does_not_exist_444445.org") in [
             :unreachable,
             nil
           ]

    # google
    assert Checker.add(instance, @url_google) == :ok
    assert Checker.status(instance, @url_google) == nil
    assert Checker.delete(instance, @url_google) == :ok
    assert Checker.status(instance, @url_google) == :error
    assert Checker.status(instance, "https://yahoo.com") == :error
  end

  @interval 550
  test "unstable servers" do
    instance = id()

    # Set interval
    {:ok, _pid} = Checker.start(instance, interval: @interval)

    Checker.debug(:all)

    urls = [
      @url_github,
      @url_google,
      @url_unstable,
      @url_unreachable,
      @url_up,
      @url_malformed
    ]

    for url <- urls do
      assert Checker.add(instance, url) == :ok
    end

    sleep()

    results =
      for _x <- 1..10 do
        results =
          for url <- urls do
            {url, Checker.status(instance, url)}
          end

        # Wait up for server to check status
        sleep(@interval)
        results
      end
      |> List.flatten()
      |> Enum.group_by(fn {key, _value} -> key end, fn {_key, value} -> value end)

    # 200
    assert Enum.all?(results[@url_github], &(&1 == 200))
    assert Enum.all?(results[@url_google], &(&1 == 200))
    assert Enum.all?(results[@url_up], &(&1 == 200))

    # :unreachable
    assert Enum.all?(results[@url_unreachable], &(&1 == :unreachable))

    # Unstable
    # assert Enum.any?(results[@url_unstable], &(&1 == 200))
    # assert Enum.any?(results[@url_unstable], &(&1 == :unreachable))

    # :error
    assert Enum.all?(results[@url_malformed], &(&1 == :error))

    Checker.stop(instance)
  end

  test "malformed URLs", %{instance: instance} do
    url = "ttps://google.com"
    Checker.add(instance, url)
    sleep()

    assert Checker.state(instance) == %{"ttps://google.com" => :error}
  end

  test "job_pid/1", %{instance: instance, pid: _pid} do
    Checker.add(instance, @url_up)
    sleep(50)

    job_pid = Checker.job_pid(instance, @url_up)
    assert is_pid(job_pid)

    # Kill worker and see if it's kicked back in by the supervisor
    Process.exit(job_pid, :kill)
    sleep(5)
    refute Process.alive?(job_pid)

    new_job_pid = Checker.job_pid(instance, @url_up)
    assert job_pid != new_job_pid
    assert job_pid != Checker.job_pid(instance, @url_up)
  end

  describe "config/1" do
    test "no config", %{instance: instance} do
      %{interval: interval} = Checker.config(instance)

      assert interval == Checker.__default_interval__()
    end

    test "with config", %{test: test_name} do
      {:ok, _pid} = Checker.start(test_name, interval: 12_345)
      assert %{interval: 12_345} = Checker.config(test_name)
      Checker.stop(test_name)
    end
  end

  test "add/2 and delete/2", %{instance: instance} do
    for n <- 101..200 do
      url = "https://#{n}.google.com"
      Checker.add(instance, url)
      url
    end

    assert Checker.list(instance) |> Enum.count() == 100

    for n <- 131..180 do
      url = "https://#{n}.google.com"
      Checker.delete(instance, url)
      url
    end

    assert Checker.list(instance) |> Enum.count() == 50
  end

  describe "delete" do
    test "delete malformed", %{instance: instance, worker_pid: worker_pid} do
      Checker.add(instance, @url_malformed)

      # TODO: TEST THIS AND FIX
      assert cast(worker_pid, {:delete, @url_malformed}) == %{}
      assert cast(worker_pid, {:delete, @url_malformed}) == %{}

      # Delete a malformed URL that has not been added
      assert cast(worker_pid, {:delete, "zzzzzzzzzzz"}) == %{}
    end

    test "delete/1", %{instance: instance, worker_pid: worker_pid} do
      # Delete a URL when none has not been added yet
      assert cast(worker_pid, {:delete, "http://wikipedia.org"}) == %{}

      urls = [
        @url_github,
        @url_google,
        @url_unstable,
        @url_unreachable,
        @url_up,
        @url_malformed
      ]

      for url <- urls do
        Checker.add(instance, url)
      end

      ## Delete URL and add it back
      state = cast(worker_pid, {:delete, @url_up})
      assert Enum.count(state) == 5
      state = cast(worker_pid, {:add, @url_up})
      assert Enum.count(state) == 6

      # TODO: TEST THIS AND FIX
      # cast(worker_pid, {:delete, @url_malformed})
      cast(worker_pid, {:delete, @url_google})
      state = cast(worker_pid, {:delete, @url_up})
      assert Enum.count(state) == 4

      # Delete a URL that has not been added
      cast(worker_pid, {:delete, "http://wikipedia.org"})

      # Delete a malformed URL that has not been added
      cast(worker_pid, {:delete, "zzzzzzzzzzz"})
      cast(worker_pid, {:delete, "dfasfdasssss"})
      state = cast(worker_pid, {:delete, "dfasfdasssss"})
      assert Enum.count(state) == 4
    end

    test "delete  repeteadly", %{instance: instance} do
      Checker.add(instance, @url_up)
      Checker.add(instance, @url_unreachable)
      Checker.add(instance, @url_google)

      Checker.delete(instance, @url_unreachable)
      Checker.delete(instance, @url_unreachable)
      Checker.delete(instance, @url_unreachable)
    end
  end

  describe "reset" do
    test "reset/1", %{instance: instance} do
      urls = [
        @url_github,
        @url_google,
        @url_unstable,
        @url_unreachable,
        @url_up,
        @url_malformed
      ]

      for url <- urls do
        Checker.add(instance, url)
      end

      sleep(10)

      assert Checker.list(instance) |> map_size() == 6
      assert Checker.reset(instance) == %{}
      assert Checker.list(instance) == %{}
      assert Checker.state(instance) == %{}
      assert %{interval: @default_interval} = Checker.config(instance)
    end

    test "reset  twice", %{instance: instance} do
      urls = [
        @url_github,
        @url_google,
        @url_unstable,
        @url_unreachable,
        @url_up,
        @url_malformed
      ]

      for url <- urls do
        Checker.add(instance, url)
      end

      assert Checker.reset(instance) == %{}
      assert Checker.reset(instance) == %{}
    end
  end
end

defmodule Checker.MixProject do
  use Mix.Project

  def project do
    [
      app: :checker,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      compilers:
        if Mix.env() in [:dev, :test] do
          [:unused] ++ Mix.compilers()
        else
          Mix.compilers()
        end,
      unused: unused()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Checker.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:req, "~> 0.2.2"},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:gradient, github: "esl/gradient", branch: "issues/98-fix-manual-annotations"},
      {:mix_unused, "~> 0.3.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      validate: [
        "format --check-formatted",
        "deps.unlock --check-unused",
        "compile",
        "compile --warnings-as-errors",
        "dialyzer",
        "gradient",
        "docs",
        "credo --strict"
      ],
      prepare: [
        "format",
        "deps.clean --unused --unlock",
        "deps.unlock --unsued"
      ],
      setup: [
        "deps.get",
        "deps.update --all"
      ],
      all: [
        "setup",
        "prepare",
        "validate",
        test_isolated()
      ]
    ]
  end

  defp test_isolated() do
    fn _args ->
      env = %{"MIX_ENV" => "test"}

      with {:"test setup", {_, 0}} <- {:"test setup", System.cmd("mix", ~w[setup], env: env)},
           {:test, {_, 0}} <- {:test, System.cmd("mix", ~w[test], env: env)} do
        true
      else
        {type, {output, _}} ->
          IO.puts(output)
          raise("#{type} failed.")
      end
    end
  end

  defp unused() do
    [
      ignore: [
        {:_, :"::", 2},
        {:_, :__using__, 1},
        Checker,
        {Checker.Instance, :child_spec, 1},
        {Checker.Instance, :start_link, 1},
        {Checker.Job, :child_spec, 1},
        {Checker.Job, :start_link, 1},
        {Checker.JobSupervisor, :child_spec, 1},
        {Checker.JobSupervisor, :start_link, 1},
        {Checker.Server, :child_spec, 1},
        {Checker.Server, :start_link, 1},
        {Checker.Util, :unique_id, 0},
        {Checker.Mock, :fetch_url_status, 1},
        {Checker.Util, :fetch_url_status, 1},
        {Checker.Util, :child_pid, 1},
        {GenServerSync, :await, 3}
      ]
    ]
  end
end

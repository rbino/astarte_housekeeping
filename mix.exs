defmodule Astarte.Housekeeping.Mixfile do
  use Mix.Project

  def project do
    [
     app: :astarte_housekeeping,
     version: "0.1.0",
     build_path: "_build",
     config_path: "config/config.exs",
     deps_path: "deps",
     lockfile: "mix.lock",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: ["coveralls": :test, "coveralls.detail": :test, "coveralls.post": :test, "coveralls.html": :test],
     deps: deps() ++ astarte_required_modules(System.get_env("ASTARTE_IN_UMBRELLA"))
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Astarte.Housekeeping, []}
    ]
  end

  defp astarte_required_modules("true") do
    [
      {:astarte_core, in_umbrella: true},
      {:astarte_rpc, in_umbrella: true}
    ]
  end

  defp astarte_required_modules(_) do
    [
      {:astarte_core, git: "https://git.ispirata.com/Astarte-NG/astarte_core"},
      {:astarte_rpc, git: "https://git.ispirata.com/Astarte-NG/astarte_rpc"}
    ]
  end

  defp deps do
    [
      {:cqex, "~> 0.2.0"},
      {:cqerl, github: "matehat/cqerl"},
      {:re2, git: "https://github.com/tuncer/re2.git", tag: "v1.7.2", override: true},
      {:distillery, "~> 1.4", runtime: false},
      {:excoveralls, "~> 0.6", only: :test}
    ]
  end
end

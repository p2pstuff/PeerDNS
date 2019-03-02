defmodule PeerDNS.MixProject do
  use Mix.Project

  def project do
    [
      app: :peerdns,
      version: "0.1.1",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {PeerDNS.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:distillery, "~> 2.0"},
      {:bencode, "~> 0.3.0"},
      {:httpotion, "~> 3.1.0"},
      {:plug, "~> 1.6"},
      {:cowboy, "~> 2.4"},
      {:plug_cowboy, "~> 2.0.1"},
      {:cors_plug, "~> 2.0"},
      {:poison, "~> 3.1"},
      {:enacl, git: "https://github.com/jlouis/enacl.git", tag: "0.16.0"},
      {:dns, "~> 2.1.2"},
    ]
  end
end

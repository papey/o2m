defmodule O2M.MixProject do
  use Mix.Project

  def project do
    [
      app: :o2m,
      version: "0.7.8",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [
        # The main page in the docs
        main: "O2M",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {O2M.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:nostrum, "~> 0.4"},
      {:httpoison, "~> 1.6"},
      {:elixir_feed_parser, "~> 0.0.1"},
      {:timex, "~> 3.5"},
      {:jason, "~> 1.1"},
      {:tesla, "~> 1.3.0"},
      {:gen_state_machine, "~> 3.0.0"}
    ]
  end
end

defmodule O2M.MixProject do
  use Mix.Project

  def project do
    [
      app: :o2m,
      version: "0.15.0",
      elixir: "~> 1.19",
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
      {:nostrum,
       git: "https://github.com/Kraigie/nostrum.git",
       ref: "5d5212d72feb2a4b78391a6297bf05f1937ee070"},
      {:elixir_feed_parser, "~> 2.1"},
      {:timex, "~> 3.7"},
      {:jason, "~> 1.3"},
      {:hackney, "~> 1.17"},
      {:httpoison, "~> 2.3.0"},
      {:gen_state_machine, "~> 3.0.0"},
      {:ssl_verify_fun, ">= 1.1.7"}
    ]
  end
end

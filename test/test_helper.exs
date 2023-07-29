Application.ensure_all_started(:hackney)

ExUnit.configure(exclude: :down)
ExUnit.start()

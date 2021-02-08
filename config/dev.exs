import Config

config :mix_test_watch,
  clear: true,
  tasks: [
    "format",
    "test",
    "credo --strict",
    "sobelow --verbose --config --skip"
    # "dialyzer" Think about this one
  ]

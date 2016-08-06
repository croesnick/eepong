defmodule EEPong do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Start the endpoint when the application starts
      supervisor(EEPong.Endpoint, []),
      # Start the Ecto repository
      worker(EEPong.Repo, []),
      # Here you could define other workers and supervisors as children
      # worker(EEPong.Worker, [arg1, arg2, arg3]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: EEPong.Supervisor]
    Supervisor.start_link(children, opts)

    EEPong.Users.start_link
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    EEPong.Endpoint.config_change(changed, removed)
    :ok
  end
end

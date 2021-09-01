defmodule MishkaDatabase.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {MishkaDatabase.Cache.MnesiaToken, []},
      {MishkaDatabase.Cache.RandomCode, []},
      MishkaDatabase.Repo,
      MishkaDatabase.Public.SettingAgent,
      {Task.Supervisor, name: MishkaDatabase.Public.ReStartSettingAgentTaskSupervisor}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MishkaDatabase.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

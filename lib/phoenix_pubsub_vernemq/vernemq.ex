defmodule Phoenix.PubSub.VerneMQ do
  use Supervisor
  
  def start_link(name, _options) do
    Supervisor.start_link(__MODULE__, name,
                          name: Module.concat(name, Supervisor))
  end

  def init(name) when is_atom(name) do
    local_name = Module.concat(name, Local)
    children = [
      worker(Phoenix.PubSub.Local, [local_name]),
      worker(Phoenix.PubSub.VerneMQ.Server, [[name: name, local_name: local_name]]),
    ]

    supervise children, strategy: :one_for_all
  end
end

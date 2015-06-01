defmodule Phoenix.PubSub.VerneMQ do
  use Supervisor

  def start_link(name, opts) do

    Supervisor.start_link(__MODULE__, [name, opts],
                          name: Module.concat(name, Supervisor))
  end

  @defaults [host: "localhost",
             port: 1883,
             client_id: "phoenix_vernemq",
             publish_qos: 0,
             subscribe_qos: 0]

  def init([name, opts]) when is_atom(name) do
    local_name = Module.concat(name, Local)

    opts = Keyword.merge(@defaults, opts)
    opts = Keyword.merge(opts, host: String.to_char_list(opts[:host]))
    opts = Keyword.merge(opts, client_id: String.to_char_list(opts[:client_id]))
    opts = Keyword.merge(opts, [name: name, local_name: local_name])

    children = [
      worker(Phoenix.PubSub.Local, [local_name]),
      worker(Phoenix.PubSub.VerneMQ.Server, [opts]),
    ]

    supervise children, strategy: :one_for_all
  end
end

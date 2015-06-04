defmodule Phoenix.PubSub.VerneMQ do
  use Supervisor

  def start_link(name, opts) do
    supervisor_name = Module.concat(name, Supervisor)
    Supervisor.start_link(__MODULE__, [name, opts],
                          name: supervisor_name)
  end

  @defaults [host: "localhost",
             port: 1883,
             client_id: "phoenix_vernemq",
             publish_qos: 0,
             subscribe_qos: 0,
             reconnect_timeout: 5,
             keepalive_interval: 60,
             clean_session: true]

  def init([server_name, opts]) when is_atom(server_name) do
    local_name = Module.concat(server_name, Local)
    emqtt_name = Module.concat(server_name, EMQTT)

    opts = Keyword.merge(@defaults, opts)
    opts = Keyword.merge(opts, host: String.to_char_list(opts[:host]))
    opts = Keyword.merge(opts, client_id: String.to_char_list(opts[:client_id]))
    opts = Keyword.merge(opts, [name: server_name,
                                local_name: local_name,
                                emqtt_name: emqtt_name])

    emqtt_opts =
      [host: Keyword.fetch!(opts, :host),
       port: Keyword.fetch!(opts, :port),
       client: Keyword.fetch!(opts, :client_id),
       server_name: server_name,
       local_name: local_name,
       emqtt_name: emqtt_name]

    children = [
      worker(Phoenix.PubSub.Local, [local_name]),
      worker(Phoenix.PubSub.VerneMQ.Server, [opts]),
      worker(Phoenix.PubSub.VerneMQ.Conn, [emqtt_opts]),
    ]

    supervise children, strategy: :one_for_all
  end
end

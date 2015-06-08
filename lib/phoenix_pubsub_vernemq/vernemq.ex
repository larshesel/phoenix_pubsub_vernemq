defmodule Phoenix.PubSub.VerneMQ do
  use Supervisor

  def start_link(name, opts) do
    supervisor_name = Module.concat(name, Supervisor)
    Supervisor.start_link(__MODULE__, [name, opts],
                          name: supervisor_name)
  end

  def init([server_name, opts]) when is_atom(server_name) do
    local_name = Module.concat(server_name, Local)
    emqtt_name = Module.concat(server_name, EMQTT)

    server_opts = [publish_qos: Keyword.get(opts, :publish_qos, 0),
                   subscribe_qos: Keyword.get(opts, :subscribe_qos, 0),
                   server_name: server_name,
                   local_name: local_name,
                   emqtt_name: emqtt_name]

    emqtt_opts =
      [host: Keyword.get(opts, :host, "localhost") |> String.to_char_list,
       port: Keyword.get(opts, :port, 1883),
       username: Keyword.get(opts, :username, :undefined),
       password: Keyword.get(opts, :password, :undefined),
       client: Keyword.get(opts, :client_id, "phoenix_vernemq") |> String.to_char_list,
       clean_session: Keyword.get(opts, :clean_session, true),
       reconnect_timeout: Keyword.get(opts, :reconnect_timeout, 5),
       keepalive_interval: Keyword.get(opts, :keepalive_interval, 60),
       emqtt_name: emqtt_name,
       server_name: server_name,
       local_name: local_name]

    children = [
      worker(Phoenix.PubSub.Local, [local_name]),
      worker(Phoenix.PubSub.VerneMQ.Server, [server_opts]),
      worker(Phoenix.PubSub.VerneMQ.Conn, [emqtt_opts]),
    ]

    supervise children, strategy: :one_for_all
  end
end

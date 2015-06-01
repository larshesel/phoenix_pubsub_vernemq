defmodule Phoenix.PubSub.VerneMQ.Server do
  @behaviour :gen_emqtt
  require Logger
  alias Phoenix.PubSub.Local

  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, [name: Keyword.fetch!(opts, :name)])
  end

  def init(opts) when is_list(opts) do
    name = Keyword.fetch!(opts, :name)
    local_name = Keyword.fetch!(opts, :local_name)

    emqtt_state = %{name: name,
                    local_name: local_name,
                    host: Keyword.fetch!(opts, :host),
                    port: Keyword.fetch!(opts, :port),
                    client: Keyword.fetch!(opts, :client_id),
                    adapter_pid: self()}
    emqtt_opts = [host: emqtt_state.host,
                  port: emqtt_state.port,
                  client: emqtt_state.client]
    {:ok, pid} = :gen_emqtt.start_link(__MODULE__, emqtt_state, emqtt_opts)
    state = %{emqtt_pid: pid,
              local_name: local_name}
    {:ok, state}
  end
  def init(emqtt_state) do
    {:ok, emqtt_state}
  end

  # emqtt callbacks
  def on_connect(emqtt_state) do
    log("on_connect")
    {:ok, emqtt_state}
  end

  def on_connect_error(_reason, emqtt_state) do
    log("on_connect_error")
    {:ok, emqtt_state}
  end

  def on_disconnect(emqtt_state) do
    log("on_disconnect")
    {:ok, emqtt_state}
  end

  def on_subscribe(topics, emqtt_state) do
    log("on_subscribe")
    IO.inspect {:on_subscribe, topics}
    {:ok, emqtt_state}
  end

  def on_unsubscribe(_topics, emqtt_state) do
    log("on_unsubscribe")
    {:ok, emqtt_state}
  end

  def on_publish(topic, payload, emqtt_state) do
    msg = :erlang.binary_to_term(payload)
    log("on_publish #{inspect {topic, emqtt_state.local_name, msg}}")
    Local.broadcast(emqtt_state.local_name, :none, :erlang.list_to_binary(topic), msg)
    {:ok, emqtt_state}
  end

  # Handle channel events
  def handle_call({:subscribe, pid, topic, opts}, _from, state) do
    log("#{inspect {:subscribe, pid, topic, opts}}")
    qos = 0
    :gen_emqtt.subscribe(state.emqtt_pid, :erlang.binary_to_list(topic), qos)
    response = {:perform, {Local, :subscribe, [state.local_name, pid, topic, opts]}}
    {:reply, response, state}
  end
  def handle_call({:unsubscribe, pid, topic}, _from, state) do
    log("#{inspect {:unsubscribe, pid, topic}}")
    :gen_emqtt.unsubscribe(state.emqtt_pid, :erlang.binary_to_list(topic))
    response = {:perform, {Local, :unsubscribe, [state.local_name, pid, topic]}}
    {:reply, response, state}
  end
  def handle_call({:broadcast, pid, topic, message}, _from, state) do
    log("#{inspect {:broadcast, pid, topic, message}}")
    qos = 0
    :gen_emqtt.publish(state.emqtt_pid, :erlang.binary_to_list(topic), :erlang.term_to_binary(message), qos)
    response = :ok
    {:reply, response, state}
  end

  def handle_cast(msg, state) do
    log("#{inspect {:handle_cast, msg, state}}")
    {:noreply, state}
  end

  def handle_info(msg, state) do
    IO.inspect {:handle_info, msg, state}
    {:reply, :ok, state}
  end

  def terminate(_reason, _state), do: :ok
  def code_change(_oldvsn, state, _extra), do: {:ok, state}

  defp log(term), do: Logger.info("VerneMQ>> #{term}")
end

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
                    subscribe_qos: Keyword.fetch!(opts, :subscribe_qos),
                    topic: "phx:#{name}"}
    emqtt_opts = [host: Keyword.fetch!(opts, :host),
                  port: Keyword.fetch!(opts, :port),
                  client: Keyword.fetch!(opts, :client_id)]
    {:ok, pid} = :gen_emqtt.start_link(__MODULE__, emqtt_state, emqtt_opts)
    state = %{emqtt_pid: pid,
              topic: emqtt_state.topic,
              publish_qos: Keyword.fetch!(opts, :publish_qos),
              local_name: local_name}
    {:ok, state}
  end
  def init(emqtt_state) do
    {:ok, emqtt_state}
  end

  # emqtt callbacks
  def on_connect(emqtt_state) do
    :ok = :gen_emqtt.subscribe(self(),
                               :erlang.binary_to_list(emqtt_state.topic),
                               emqtt_state.subscribe_qos)
    {:ok, emqtt_state}
  end

  def on_connect_error(_reason, emqtt_state) do
    {:ok, emqtt_state}
  end

  def on_disconnect(emqtt_state) do
    {:ok, emqtt_state}
  end

  def on_subscribe(_topics, emqtt_state) do
    {:ok, emqtt_state}
  end

  def on_unsubscribe(_topics, emqtt_state) do
    {:ok, emqtt_state}
  end

  def on_publish(_topic, vernemq_msg, emqtt_state) do
    {from_node, from_pid, msg} = :erlang.binary_to_term(vernemq_msg)

    if from_node == node do
      Local.broadcast(emqtt_state.local_name, from_pid, msg.topic, msg)
    else
      Local.broadcast(emqtt_state.local_name, :none, msg.topic, msg)
    end
    {:ok, emqtt_state}
  end

  # Handle channel events
  def handle_call({:subscribe, pid, topic, opts}, _from, state) do
    response = {:perform, {Local, :subscribe, [state.local_name, pid, topic, opts]}}
    {:reply, response, state}
  end
  def handle_call({:unsubscribe, pid, topic}, _from, state) do
    response = {:perform, {Local, :unsubscribe, [state.local_name, pid, topic]}}
    {:reply, response, state}
  end
  def handle_call({:broadcast, from_pid, _topic, msg}, _from, state) do
    vernemq_msg = {node, from_pid, msg}
    :ok = :gen_emqtt.publish(state.emqtt_pid,
                             :erlang.binary_to_list(state.topic),
                             :erlang.term_to_binary(vernemq_msg),
                             state.publish_qos)
    response = :ok
    {:reply, response, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:reply, :ok, state}
  end

  def terminate(_reason, _state), do: :ok
  def code_change(_oldvsn, state, _extra), do: {:ok, state}
end

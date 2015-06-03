defmodule Phoenix.PubSub.VerneMQ.Server do
  @behaviour :gen_emqtt
  alias Phoenix.PubSub.Local

  # Client
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, [name: Keyword.fetch!(opts, :name)])
  end

  # Callbacks.
  def init(opts) when is_list(opts) do
    name = Keyword.fetch!(opts, :name)
    local_name = Keyword.fetch!(opts, :local_name)
    emqtt_state =
      %{server_pid: self,
        local_name: local_name}
    emqtt_opts =
      [host: Keyword.fetch!(opts, :host),
       port: Keyword.fetch!(opts, :port),
       client: Keyword.fetch!(opts, :client_id)]
    {:ok, pid} = :gen_emqtt.start_link(__MODULE__, emqtt_state, emqtt_opts)
    state =
      %{emqtt_pid: pid,
        name: name,
        publish_qos: Keyword.fetch!(opts, :publish_qos),
        subscribe_qos: Keyword.fetch!(opts, :subscribe_qos),
        local_name: local_name}
    receive do
      :connected -> :ok
    end
    {:ok, state}
  end
  def init(emqtt_state) do
    {:ok, emqtt_state}
  end

  # emqtt callbacks
  def on_connect(emqtt_state) do
    send emqtt_state.server_pid, :connected
    {:ok, emqtt_state}
  end

  def on_connect_error(_reason, emqtt_state) do
    {:ok, emqtt_state}
  end

  def on_disconnect(emqtt_state) do
    {:ok, emqtt_state}
  end

  def on_subscribe([{topic, _qos}], emqtt_state) do
    send emqtt_state.server_pid, {:subscribed, :erlang.list_to_binary(topic)}
    {:ok, emqtt_state}
  end

  def on_unsubscribe([topic], emqtt_state) do
    send emqtt_state.server_pid, {:unsubscribed, :erlang.list_to_binary(topic)}
    {:ok, emqtt_state}
  end

  def on_publish(topic, msg, emqtt_state) do
    :ok = Local.broadcast(emqtt_state.local_name,
                          :none,
                          :erlang.list_to_binary(topic),
                          :erlang.binary_to_term(msg))
    {:ok, emqtt_state}
  end

  # Handle channel events
  def handle_call({:subscribe, pid, topic, opts}, _from, state) do
    subscribers = Local.subscribers(state.local_name, topic)
    if Dict.size(subscribers) == 0 do
      :ok = :gen_emqtt.subscribe(state.emqtt_pid,
                                 :erlang.binary_to_list(topic),
                                 state.subscribe_qos)
      # TODO: this is a hack to make it blocking
      receive do
        {:subscribed, ^topic} ->
          :ok = Local.subscribe(state.local_name, pid, topic, opts)
          {:reply, :ok, state}
      after
        5000 ->
          Logger.warn("subscribe on MQTT server failed: #{topic}")
          {:reply, {:error, {:subscription_failed, topic}}, state}
      end
    else
      :ok = Local.subscribe(state.local_name, pid, topic, opts)
      {:reply, :ok, state}
    end
  end
  def handle_call({:unsubscribe, pid, topic}, _from, state) do
    subscribers = Local.subscribers(state.local_name, topic)
    if Dict.size(subscribers) == 1 do
      :ok = :gen_emqtt.unsubscribe(state.emqtt_pid,
                                   :erlang.binary_to_list(topic))
      # TODO: this is a hack to make it blocking
      receive do
        {:unsubscribed, ^topic} ->
          :ok = Local.unsubscribe(state.local_name, pid, topic)
          {:reply, :ok, state}
      after
        5000 ->
          Logger.warn("unsubscribe on MQTT server failed: #{topic}")
          {:reply, {:error, {:unsubscription_failed, topic}}, state}
      end
    else
      :ok = Local.unsubscribe(state.local_name, pid, topic)
      {:reply, :ok, state}
    end
  end
  def handle_call({:broadcast, _pid, topic, msg}, _from, state) do
    :ok = publish(state.emqtt_pid, topic, msg, state.publish_qos)
    {:reply, :ok, state}
  end

  defp publish(pid, topic, msg, qos) when is_binary(topic) do
    publish(pid, :erlang.binary_to_list(topic), msg, qos)
  end
  defp publish(pid, topic, msg, qos) when is_list(topic) do
    :ok = :gen_emqtt.publish(pid, topic, :erlang.term_to_binary(msg), qos)
  end

  def handle_cast(_msg, state) do
    {:reply, state}
  end

  def handle_info(_msg, state) do
    {:reply, :ok, state}
  end

  def terminate(_reason, _state), do: :ok
  def code_change(_oldvsn, state, _extra), do: {:ok, state}
end

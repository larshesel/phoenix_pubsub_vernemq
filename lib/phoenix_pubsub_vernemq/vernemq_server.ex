defmodule Phoenix.PubSub.VerneMQ.Server do
  use GenServer
  alias Phoenix.PubSub.Local
  require Logger

  # Client
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, [name: Keyword.fetch!(opts, :server_name)])
  end

  # Callbacks.
  def init(opts) when is_list(opts) do
    state =
      %{local_name: Keyword.fetch!(opts, :local_name),
        emqtt_name: Keyword.fetch!(opts, :emqtt_name),
        publish_qos: Keyword.fetch!(opts, :publish_qos),
        subscribe_qos: Keyword.fetch!(opts, :subscribe_qos)}
    send self, :wait_for_connect
    {:ok, state}
  end

  # Handle channel events
  def handle_call({:subscribe, pid, topic, opts}, _from, state) do
    subscribers = Local.subscribers(state.local_name, topic)
    if Dict.size(subscribers) == 0 do
      :ok = :gen_emqtt.subscribe(state.emqtt_name,
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
      :ok = :gen_emqtt.unsubscribe(state.emqtt_name,
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
    :ok = publish(state.emqtt_name, topic, msg, state.publish_qos)
    {:reply, :ok, state}
  end

  def handle_info(:wait_for_connect, state) do
    receive do
      :connected ->
        {:noreply, state}
    end
  end

  defp publish(pid, topic, msg, qos) when is_binary(topic) do
    publish(pid, :erlang.binary_to_list(topic), msg, qos)
  end
  defp publish(pid, topic, msg, qos) when is_list(topic) do
    :ok = :gen_emqtt.publish(pid, topic, :erlang.term_to_binary(msg), qos)
  end
end

defmodule Phoenix.PubSub.VerneMQ.Conn do
  @behaviour :gen_emqtt
  alias Phoenix.PubSub.Local
  require Logger

  def start_link(opts) do
    state = %{
      server_name: Keyword.fetch!(opts, :server_name),
      local_name: Keyword.fetch!(opts, :local_name),
      }
    :gen_emqtt.start_link({:local, Keyword.fetch!(opts, :emqtt_name)},__MODULE__,state, opts)
  end

  def init(state) do
    {:ok, state}
  end

  # emqtt callbacks
  def on_connect(state) do
    Logger.info("MQTT connection established")
    send state.server_name, :connected
    {:ok, state}
  end

  def on_connect_error(reason, state) do
    Logger.warn("MQTT connection error: #{inspect reason}")
    {:ok, state}
  end

  def on_disconnect(state) do
    Logger.info("MQTT server disconnected")
    {:ok, state}
  end

  def on_subscribe([{topic, _qos}]=subscription, state) do
    Logger.debug("MQTT server subscribed: #{inspect subscription}")
    send state.server_name, {:subscribed, :erlang.list_to_binary(topic)}
    {:ok, state}
  end

  def on_unsubscribe([topic], state) do
    Logger.debug("MQTT server unsubscribed: #{inspect topic}")
    send state.server_name, {:unsubscribed, :erlang.list_to_binary(topic)}
    {:ok, state}
  end

  def on_publish(topic, msg, state) do
    Logger.debug("MQTT server published #{inspect {topic, msg}}")
    :ok = Local.broadcast(state.local_name, :none, :erlang.list_to_binary(topic), :erlang.binary_to_term(msg))
    {:ok, state}
  end

  def handle_call(msg, _from, state) do
    {:stop, {:error, {:unexpected_msg, msg}}, state}
  end

  def handle_cast(msg, state) do
    {:stop, {:error, {:unexpected_msg, msg}}, state}
  end

  def handle_info(msg, state) do
    Logger.warn("handle_info: #{inspect msg}")
    {:stop, {:error, {:unexpected_msg, msg}}, state}
  end

  def terminate(_reason, _state), do: :ok
  def code_change(_oldvsn, state, _extra), do: {:ok, state}
end

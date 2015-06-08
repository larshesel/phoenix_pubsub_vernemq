## Phoenix.Pubsub.VerneMQ

[![Build Status](https://travis-ci.org/larshesel/phoenix_pubsub_vernemq.svg?branch=master)](https://travis-ci.org/larshesel/phoenix_pubsub_vernemq)

A VerneMQ PubSub adapter for the
[Phoenix framework](http://www.phoenixframework.org/).

This adapter was built for [VerneMQ](https://verne.mq/) but should
work with any MQTT server.

## Configuration

In order to use the VerneMQ pubsub adapter in phoenix, add it and
`vmq_commons` as a dendency to your `mix.exs` file:

```Elixir
defp deps do
  [{:vmq_commons, git: "https://github.com/erlio/vmq_commons.git"},
   {:phoenix_pubsub_vernemq, "~> 0.0.2"}],
end
```

and configure your endpoint appropriately:

```Elixir
config :my_app, MyApp.Endpoint,
  ...
  pubsub: [name: HelloPhoenix.PubSub,
           adapter: Phoenix.PubSub.VerneMQ,
           host: "localhost",
           port: 1883,
           client_id: "test_client"]
```

The complete list of configuration options:

* `:host` - The MQTT server hostname or ip, default: `"localhost"`
* `:port` - The MQTT server port number, default: `1883`
* `:username` - MQTT user name
* `:password` - MQTT password
* `:client_id` - MQTT client id, default: `"phoenix_vernemq"`
* `:publish_qos` - QoS level for publishing, default: `0`
* `:subscribe_qos` - QoS level for subscribing, default: `0`
* `:clean_session` - default: `true`
* `:reconnect_timeout` - default in seconds: `5`
* `:keepalive_interval` - defaults: `60`

## Notes

This work was inspired by the
[Redis pubsub adapter](https://github.com/phoenixframework/phoenix_pubsub_redis)
for Phoenix.

The VerneMQ pubsub adapter is licensed under the Apache License Version 2.

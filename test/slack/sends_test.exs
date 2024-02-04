defmodule Slack.SendsTest do
  use ExUnit.Case
  alias Slack.Sends

  defmodule FakeWebsocketClient do
    def send({:text, json}, socket) do
      {json, socket}
    end

    def cast(pid, {:text, json}) do
      {pid, json}
    end
  end

  test "send_raw sends slack formatted to client" do
    result = Sends.send_raw(~s/{"text": "foo"}/, %{process: 123, client: FakeWebsocketClient})
    assert result == {123, ~s/{"text": "foo"}/}
  end

  test "send_message sends message formatted to client" do
    {nil, result} = Sends.send_message("hello", "channel", %{process: nil, client: FakeWebsocketClient})
    assert %{channel: "channel", text: "hello", type: "message"} = Jason.decode!(result, keys: :atoms)
  end

  test "send_message understands #channel names" do
    slack = %{
      process: nil,
      client: FakeWebsocketClient,
      channels: %{"C456" => %{name: "channel", id: "C456"}}
    }

    {nil, result} = Sends.send_message("hello", "#channel", slack)
    assert %{channel: "C456", text: "hello", type: "message"} = Jason.decode!(result, keys: :atoms)
  end

  test "send_message understands @user names" do
    slack = %{
      process: nil,
      client: FakeWebsocketClient,
      users: %{"U123" => %{name: "user", id: "U123"}},
      ims: %{"D789" => %{user: "U123", id: "D789"}}
    }

    {nil, result} = Sends.send_message("hello", "@user", slack)
    assert %{channel: "D789", text: "hello", type: "message"} = Jason.decode!(result, keys: :atoms)
  end

  test "send_message understands user ids (Uxxx)" do
    slack = %{
      process: nil,
      client: FakeWebsocketClient,
      users: %{"U123" => %{name: "user", id: "U123"}},
      ims: %{"D789" => %{user: "U123", id: "D789"}}
    }

    {nil, result} = Sends.send_message("hello", "U123", slack)
    assert %{channel: "D789", text: "hello", type: "message"} = Jason.decode!(result, keys: :atoms)
  end

  test "send_message understands user ids (Wxxx)" do
    slack = %{
      process: nil,
      client: FakeWebsocketClient,
      users: %{"W123" => %{name: "user", id: "W123"}},
      ims: %{"D789" => %{user: "W123", id: "D789"}}
    }

    {nil, result} = Sends.send_message("hello", "W123", slack)
    assert %{channel: "D789", text: "hello", type: "message"} = Jason.decode!(result, keys: :atoms)
  end

  test "send_message with a thread attribute includes thread_ts in message to client" do
    slack = %{
      process: nil,
      client: FakeWebsocketClient,
      users: %{"U123" => %{name: "user", id: "U123"}},
      ims: %{"D789" => %{user: "U123", id: "D789"}}
    }

    {nil, result} = Sends.send_message("hello", "D789", slack, "1555508888.000100")

    assert %{channel: "D789", text: "hello", thread_ts: "1555508888.000100", type: "message"} = Jason.decode!(result, keys: :atoms)
  end

  test "indicate_typing sends typing notification to client" do
    {nil, result} = Sends.indicate_typing("channel", %{process: nil, client: FakeWebsocketClient})
    assert %{channel: "channel", type: "typing"} = Jason.decode!(result, keys: :atoms)
  end

  test "send_ping sends ping to client" do
    {nil, result} = Sends.send_ping(%{process: nil, client: FakeWebsocketClient})
    assert %{type: "ping"} = Jason.decode!(result, keys: :atoms)
  end

  test "send_ping with data sends ping + data to client" do
    {nil, result} = Sends.send_ping(%{foo: :bar}, %{process: nil, client: FakeWebsocketClient})
    assert %{foo: "bar", type: "ping"} = Jason.decode!(result, keys: :atoms)
  end

  test "subscribe_presence sends presence subscription message to client" do
    {nil, result} = Sends.subscribe_presence(["a_user_id"], %{process: nil, client: FakeWebsocketClient})
    assert %{ids: ["a_user_id"], type: "presence_sub"} = Jason.decode!(result, keys: :atoms)
  end

  test "subscribe_presence without ids sends presence subscription message to client" do
    {nil, result} = Sends.subscribe_presence(%{process: nil, client: FakeWebsocketClient})
    assert %{ids: [], type: "presence_sub"} = Jason.decode!(result, keys: :atoms)
  end
end

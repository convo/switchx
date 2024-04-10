defmodule SwitchX do
  ## API ##
  require Logger

  @timeout 5_000
  @doc """
  Tells FreeSWITCH not to close the socket connection when a channel hangs up.
  Instead, it keeps the socket connection open until the last event related
  to the channel has been received by the socket client.

  Returns
  ```
    {:ok, "Lingering"}
  ```

  ## Examples

      iex> SwitchX.linger(context.conn)
      {:ok, "Lingering"}
  """
  @spec linger(conn :: pid()) :: term
  def linger(conn),
    do: linger(conn, @timeout)

  @spec linger(conn :: pid(), timeout :: non_neg_integer()) :: term
  def linger(conn, timeout),
    do: safe_gen_call(conn, {:linger}, timeout)

  @doc """
  Reply the auth/request package from FreeSWITCH.

  Returns
  ```
    {:ok, "Accepted"} | {:error, "Denied"}
  ```

  ## Examples
      iex> SwitchX.auth(conn, "ClueCon")
      {:ok, "Accepted"}

      iex> SwitchX.auth(conn, "Incorrect")
      {:error, "Denied"}
  """
  @spec auth(conn :: pid(), password :: String.t()) :: {:ok, term} | {:error, term}
  def auth(conn, password),
    do: auth(conn, password, @timeout)

  @spec auth(conn :: pid(), password :: String.t(), timeout :: non_neg_integer()) :: {:ok, term} | {:error, term}
  def auth(conn, password, timeout),
    do: safe_gen_call(conn, {:auth, password}, timeout)

  @doc """
  Send a FreeSWITCH API command.

  Returns
  ```
    {:ok, term}
  ```

  ## Examples

      iex> SwitchX.api(
            conn,
            "uuid_getvar a1024ff5-a5b3-4c0a-abd3-fd4a89508b5b current_application"
           )
      %SwitchX.Event{
        body: "park",
        headers: %{"Content-Length" => "4", "Content-Type" => "api/response"}
      }
  """
  @spec api(conn :: pid(), args :: String.t()) :: {:ok, term}
  def api(conn, args),
    do: api(conn, args, @timeout)

  @spec api(conn :: pid(), args :: String.t(), timeout :: non_neg_integer()) :: {:ok, term}
  def api(conn, args, timeout),
    do: safe_gen_call(conn, {:api, args}, timeout)

  @doc """
  Send a FreeSWITCH API command, non-blocking mode.
  This will let you execute a job in the background, and the result will be sent as an BACKGROUND_JOB event
  with an indicated UUID to match the reply to the command.
  """
  @spec bg_api(conn :: pid(), args :: String.t()) :: {:ok, event :: SwitchX.Event}
  def bg_api(conn, args),
    do: bg_api(conn, args, @timeout)

  @spec bg_api(conn :: pid(), args :: String.t(), timeout :: non_neg_integer()) :: {:ok, event :: SwitchX.Event}
  def bg_api(conn, args, timeout),
    do: safe_gen_call(conn, {:bgapi, args}, timeout)

  @doc """
  Enable or disable events by class or all.

  Returns
  ```
    :ok
  ```

  ## Examples

      iex> SwitchX.listen_event(conn, "BACKGROUND_JOB")
      {:ok, %SwitchX.Event{}}
  """
  @spec listen_event(conn :: pid(), event_name :: String.t()) :: :ok
  def listen_event(conn, event_name),
    do: listen_event(conn, event_name, @timeout)

  @spec listen_event(conn :: pid(), event_name :: String.t(), timeout :: non_neg_integer()) :: :ok
  def listen_event(conn, event_name, timeout),
    do: safe_gen_call(conn, {:listen_event, event_name}, timeout)

  @doc """
  Send an event into the event system (multi line input for headers).
  ```
  sendevent <event-name>
  <headers>

  <body>
  ```

  Returns
  ```
    {:ok, term}
  ```

  ## Examples

      iex> SwitchX.filter(conn, "Event-Name CHANNEL_EXECUTE")
      {:ok, %SwitchX.Event{}}
  """
  @spec filter(conn :: pid(), args :: String.t()) :: {:ok, any()}
  def filter(conn, args),
    do: filter(conn, args, @timeout)

  @spec filter(conn :: pid(), args :: String.t(), timeout :: non_neg_integer()) :: {:ok, any()}
  def filter(conn, args, timeout),
    do: safe_gen_call(conn, {:filter, args}, timeout)

  @doc """
  Send an event into the event system (multi line input for headers).
  ```
  sendevent <event-name>
  <headers>

  <body>
  ```

  Returns
  ```
    {:ok, term}
  ```

  ## Examples

      iex>  event_headers =
        SwitchX.Event.Headers.new(%{
          "profile": "external",
        })
      event = SwitchX.Event.new(event_headers, "")
      SwitchX.send_event(conn, "SEND_INFO", event)
      {:ok, response}
  """
  @spec send_event(conn :: pid(), event_name :: String.t(), event :: SwitchX.Event) :: {:ok, term}
  def send_event(conn, event_name, event) do
    send_event(conn, event_name, event, nil, @timeout)
  end

  @spec send_event(
          conn :: pid(),
          event_name :: String.t(),
          event :: SwitchX.Event,
          event_uuid :: nil | String.t(),
          timeout :: non_neg_integer()
        ) ::  {:ok, term} | :error
  def send_event(conn, event_name, event, event_uuid, timeout) do
    safe_gen_call(conn, {:sendevent, event_name, event, event_uuid}, timeout)
  end

  @doc """
  sendmsg is used to control the behavior of FreeSWITCH.
  UUID is mandatory when conn is inbound mode, and it refers to a specific call
  (i.e., a channel or call leg or session).

  Returns a payload with an command/reply event

  ## Examples

      iex> message = SwitchX.Event.Headers.new(%{
          "call-command": "hangup",
          "hangup-cause": "NORMAL_CLEARING",
        }) |> SwitchX.Event.new()

        SwitchX.send_message(conn, uuid, message)
        {:ok, event}
  """
  @spec send_message(conn :: pid(), event :: SwitchX.Event) :: {:ok, term}
  def send_message(conn, event) do
    send_message(conn, nil, event, @timeout)
  end

  @spec send_message(conn :: pid(), uuid :: nil | String.t(), event :: SwitchX.Event, timeout :: non_neg_integer()) :: {:ok, term}
  def send_message(conn, uuid, event, timeout) do
    safe_gen_call(conn, {:sendmsg, uuid, event}, timeout)
  end

  @doc """
  execute is used to invoke dialplan applications,

  ## Examples

      iex> SwitchX.execute(conn, uuid, "playback", "ivr/ivr-welcome_to_freeswitch.wav")
  """
  @spec execute(conn :: pid(), String.t(), application :: String.t(), args :: String.t()) ::
          event :: SwitchX.Event
  def execute(conn, uuid, application, args) do
    execute(conn, uuid, application, args, SwitchX.Event.new(), @timeout)
  end

  @spec execute(
          conn :: pid(),
          uuid :: String.t(),
          application :: String.t(),
          args :: String.t(),
          event :: SwitchX.Event,
          timeout :: non_neg_integer()
        ) :: event :: SwitchX.Event
  def execute(conn, uuid, application, arg, event, timeout) do
    event = put_in(event.headers, Map.put(event.headers, "call-command", "execute"))
    event = put_in(event.headers, Map.put(event.headers, "execute-app-name", application))
    event = put_in(event.headers, Map.put(event.headers, "execute-app-arg", arg))
    event = put_in(event.headers, Map.put(event.headers, "Event-UUID", UUID.uuid4()))
    send_message(conn, uuid, event, timeout)
  end

  @doc """
  The 'myevents' subscription allows your socket to receive all related events from a outbound socket session
  """
  @spec my_events(conn :: pid()) :: :ok | {:error, term}
  def my_events(conn),
    do: my_events(conn, nil, @timeout)

  @doc """
  The 'myevents' subscription allows your inbound socket connection to behave like an outbound socket connect.
  It will "lock on" to the events for a particular uuid and will ignore all other events
  """
  @spec my_events(conn :: pid(), uuid :: nil | String.t(), timeout :: non_neg_integer()) :: :ok | {:error, term}
  def my_events(conn, uuid, timeout),
    do: safe_gen_call(conn, {:myevents, uuid}, timeout)

  @doc """
  Closes the socket connection.
  """
  @spec exit(conn :: pid()) :: :ok | {:error, term}
  def exit(conn) do
    case :gen_statem.call(conn, {:exit}) do
      {:ok, event} ->
        reply =
          event.headers["Reply-Text"]
          |> String.trim("\n")
          |> String.split(" ", parts: 2)

        case reply do
          ["-ERR", term] -> {:error, term}
          ["+OK", _] -> :ok
        end

      {:error, :disconnected} ->
        :ok

      _ ->
        {:error, :unknown}
    end
  end

  @doc """
    Closes the connection (conn) and stop the socket
  """
  @spec close(conn :: pid()) :: :ok | {:error, term}
  def close(conn) do
    __MODULE__.exit(conn)
    _ok = safe_gen_call(conn, {:close}, @timeout)
    :gen_statem.stop(conn, :normal, 1_000)
  end

  @doc """
  Hang up the call with a hangup_cause.
  """
  @spec hangup(conn :: pid(), cause :: String.t()) :: :ok | {:error, term}
  def hangup(conn, hangup_cause), do: hangup(conn, nil, hangup_cause)

  @spec hangup(conn :: pid(), uuid :: String.t(), cause :: String.t()) :: :ok | {:error, term}
  def hangup(conn, uuid, hangup_cause) do
    message =
      SwitchX.Event.Headers.new(%{
        "call-command": "hangup",
        "hangup-cause": hangup_cause
      })
      |> SwitchX.Event.new()

    {:ok, event} = send_message(conn, uuid, message, @timeout)

    reply =
      event.headers["Reply-Text"]
      |> String.trim("\n")
      |> String.split(" ", parts: 2)

    case reply do
      ["-ERR", term] -> {:error, term}
      ["+OK"] -> :ok
    end
  end

  def originate(conn, aleg, bleg, :expand) do
    originate(conn, "#{aleg} #{bleg}", :expand)
  end

  def originate(conn, args, :expand) do
    originate_function = Application.get_env(:switchx, :originate_function, "originate")
    Logger.debug("Using originate function #{originate_function}")
    perform_originate(conn, "expand #{originate_function} #{args}")
  end

  def originate(conn, aleg, bleg) do
    originate(conn, "#{aleg} #{bleg}")
  end

  def originate(conn, args) do
    originate_function = Application.get_env(:switchx, :originate_function, "originate")
    Logger.debug("Using originate function #{originate_function}")
    perform_originate(conn, "#{originate_function} #{args}")
  end

  def multiset(conn, variables) when is_binary(variables) do
    execute(conn, nil, "multiset", variables)
  end

  def playback(conn, file), do: playback(conn, file, nil)

  def playback(conn, file, uuid) do
    execute(conn, uuid, "playback", file)
  end

  @spec playback_async(any(), any()) :: {:ok, pid()}
  def playback_async(conn, file), do: playback_async(conn, file, nil)

  def playback_async(conn, file, uuid) do
    Task.start(fn -> playback(conn, file, uuid) end)
  end

  defp perform_originate(conn, command) do
    {:ok, response} = api(conn, command)

    parsed_body =
      response.body
      |> String.trim("\n")
      |> String.split(" ", parts: 2)

    case parsed_body do
      ["-ERR", term] -> {:error, term}
      ["+OK", uuid] -> {:ok, uuid}
      _ -> {:error, :unknown}
    end
  end

  defp safe_gen_call(conn, command, timeout) do
    try do
      :gen_statem.call(conn, command, timeout)
    rescue
      err -> err
    end
  end
end

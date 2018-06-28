defmodule PingServer do
  @moduledoc """
  Documentation for PingServer.
 
  A GenServer extension which receives a ping at a regular interval.

  ## Example usage
  
  ```
    defmodule UsePing do
      use PingServer, interval: 10_000
    
      def start_link(thing) do
        # You can start link this way.  It will call PingServer.init(thing)
        PingServer.start_link(__MODULE__, thing, [])
      end
    
      def handle_ping(state) do
        # Even though the interval is 10 seconds, we can make it be every 1 second this way
        PingServer.ping_after(self(), 1_000)
        state
      end
    
      def handle_info(:manual_ping, state) do
        # only one ping will happen but it will happen pretty much right away.
        PingServer.ping(self())
        PingServer.ping(self())
        PingServer.ping(self())
        {:noreply, state}
      end
    end
  ```
  """

  defmacro __using__(opts) do
    {interval, opts} = Keyword.pop(opts, :interval, 1_000)
    if length(opts) > 0 do
      raise "unknown options to PingServer: #{inspect opts}"
    end

    quote location: :keep do
      def start_link(opts) do
        GenServer.start_link(__MODULE__, opts)
      end

      def handle_info(:_ping_mixin_poll, state) do
        # queue up another deferred ping by default
        PingServer.ping_after(self(), unquote(interval))
        state = apply(__MODULE__, :handle_ping, [state])
        {:noreply, state}
      end

      def handle_info({:_ping_mixin_ping_after, delay}, state) do
        Process.put(:_ping_mixin_delayed_ping, delay)
        send(self(), :_ping_mixin_process_ping_requests)
        {:noreply, state}
      end

      def handle_info(:_ping_mixin_ping, state) do
        Process.put(:_ping_mixin_immediate_ping, true)
        send(self(), :_ping_mixin_process_ping_requests)
        {:noreply, state}
      end

      def handle_info(:_ping_mixin_process_ping_requests, state) do
        immediate = Process.get(:_ping_mixin_immediate_ping, false)
        delay = Process.get(:_ping_mixin_delayed_ping, 0)
        Process.put(:_ping_mixin_immediate_ping, false)
        Process.put(:_ping_mixin_delayed_ping, 0)

        cond do
          immediate ->
            oldref = Process.get(:_ping_mixin_timer_ref)
            if oldref, do: Process.cancel_timer(oldref)
            Process.put(:_ping_mixin_timer_ref, nil)
            send(self(), :_ping_mixin_poll)
          delay > 0 ->
            oldref = Process.get(:_ping_mixin_timer_ref)
            current_delay =
              if oldref do
                oldref_delay = Process.read_timer(oldref)
                cond do
                  oldref_delay == false -> :infinity
                  true -> oldref_delay
                end
              else
                :infinity
              end
            if current_delay > delay do
              if oldref, do: Process.cancel_timer(oldref)
              ref = Process.send_after(self(), :_ping_mixin_poll, delay)
              Process.put(:_ping_mixin_timer_ref, ref)
            end
          true -> nil
        end
        {:noreply, state}
      end

      def init(arg) do
        PingServer.init(self())
        {:ok, arg}
      end

      def start_link(arg) do
        PingServer.start_link(__MODULE__, [arg], [])
      end

      defoverridable [init: 1, start_link: 1]
    end
  end

  def start_link(module, args, opts) do
    GenServer.start_link(module, args, opts)
  end

  def init(pid) do
    PingServer.ping(pid)
  end

  def ping_after(pid, delay \\ 1_000) do
    if delay < 1 do
      send(pid, :_ping_mixin_ping)
    else
      send(pid, {:_ping_mixin_ping_after, delay})
    end
    :ok
  end

  def ping(pid) do
    PingServer.ping_after(pid, 0)
  end
end

defmodule Rumbl.InfoSys do
  @backends [Rumbl.InfoSys.Wolfram]

  defmodule Result do
    defstruct score: 0, text: nil, url: nil, backend: nil
  end

  def start_link(backend, query, query_ref, owner, limit) do
    backend.start_link query, query_ref, owner, limit
  end

  def compute(query, opts \\ []) do
    limit = opts[:limit] || 10
    backends = opts[:backends] || @backends

    backends
    |> Enum.map(&spawn_query(&1, query, limit))
    |> await_results(opts)
    |> Enum.sort(&(&1.score >= &2.score))
    |> Enum.take(limit)
  end

  defp spawn_query(backend, query, limit) do
    query_ref = make_ref()
    opts = [backend, query, query_ref, self(), limit]

    {:ok, pid} = Supervisor.start_child(Rumbl.InfoSys.Supervisor, opts)

    monitor_ref = Process.monitor(pid)
    {pid, monitor_ref, query_ref}
  end

  defp await_results(children, opts) do

    #
    # timeout is for the total wait, not for each
    #
    timeout = opts[:timeout] || 5000

    #
    # 1. Create a timer to send :timedout at <timeout>
    # to be received in await_result
    #
    timer = Process.send_after(self(), :timedout, timeout)

    results = await_result children, [], :infinity
    cleanup(timer)
    results
  end

  defp await_result([head | tail], acc, timeout) do
    {pid, monitor_ref, query_ref } = head

    receive do
      {:results, ^query_ref, results} ->
        Process.demonitor(monitor_ref, [:flush])
        await_result(tail, results ++ acc, timeout)

      {:DOWN, ^monitor_ref, :process, ^pid, _reason} ->
        await_result(tail, acc, timeout)

      #
      # 2. receive :timedout from timer
      #
      :timedout ->
        kill(pid, monitor_ref)

        #
        # 3. reset the <timeout> to 0
        #
        await_result(tail, acc, 0)

    after
      timeout ->
        kill(pid, monitor_ref)
        await_result(tail, acc, 0)
    end
  end

  defp await_result([], acc, _) do
    acc
  end

  defp kill(pid, ref) do
    Process.demonitor(ref, [:flush])
    Process.exit(pid, :kill)
  end

  defp cleanup(timer) do
    #
    # 4. cancel timer, inf case it wasn't yet triggered
    # flush the :timedout message if it was already sent
    #
    :erlang.cancel_timer(timer)
    receive do
      :timedout -> :ok
    after
      0 -> :ok
    end
  end
end
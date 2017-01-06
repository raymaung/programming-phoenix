# Chapter 11 - OTP

* OTP is a way to think about concurrency and distribution
* Uses a few patterns that allow to use concurrency to build state
    * without language features that rely on mutability
* Rich abstractions for supervision and monitoring

## Managing State with Processes

* Functional programs are stateless, but still need to manage state
* In Elixir, we use concurrent process and recursion to manage state

## Building the Counter API

`counter.ex`

```
defmodule Rumbl.Counter do

  def inc(pid), do: send(pid, :inc)

  def dec(pid), do: send(pid, :ded)

  def val(pid, timeout \\ 5000) do
    ref = make_ref()
    send(pid, {:val, self(), ref})

    receive do
      {^ref, val} -> val
    after timeout -> exit(:timeout)
    end
  end

  def start_link(initial_val) do
    {:ok, spawn_link(fn -> listen(initial_val) end)}
  end

  defp listen(val) do
    receive do
      :inc -> listen(val + 1)
      :ded -> listen(val - 1)

      {:val, sender, ref} ->
        send sender, {ref, val}
        listen(val)
    end
  end
end
```

* `inc` and `dec` are **asynchronous**; just send a message and don't bother to await
* `val` sends a message and await for a response
    * to associate a response with this particular request
        * create a **unique** reference with `make_ref()`
        * `make_ref` guranteed to be globally unique
    * blocks the caller process while waiting for a response
* `^` operator in `{^ref, val} -> val` means
    * rather than reassigning the value of `ref`, match only tuples thatt have that exact `ref`

* OTP requires `start_link` function
    * accept initial start of the counter
    * its only job is to spawn a process and return `{:ok, pid}`
    * spawned process calls the private function named `listen`
* `listen` is the **engine** for the counter
    * doesn't have any global variables that hold state
    * but exploit **recursion** to manage state
    * the state of the server is wrapped up in the execution of the recursive function
    * calls itself as the last thing to be **tail recursive**
    * Elixir processes are incredibly cheap so this strategy is a great way to manage state

## Taking Our Counter for a Spin

```
$ iex -S mix

> alias Rumbl.Counter

> {:ok, counter} = Counter.start_link 0

> Counter.inc counter 

> Counter.inc counter

> Counter.val counter
2

> Counter.dec counter

> Counter.val counter
1 
```

* used concurrency and recursion to maintain state
* seprated the interface from the implementation
* used different abstractions for asynchronous and synchronous

## Building GenServers for OTP

* Library encapsulationg that Counter approach is called **OTP**
* the abstraction is called **Generic Server or GenServer**

```
defmodule Rumbl.Counter do

  use GenServer

  def inc(pid), do: GenServer.cast(pid, :inc)

  def dec(pid), do: GenServer.cast(pid, :dec)

  def val(pid) do
    GenServer.call pid, :val
  end

  def start_link(initial_val) do
    GenServer.start_link __MODULE__, initial_val
  end

  def init(initial_val) do
    {:ok, initial_val}
  end

  def handle_cast(:inc, val) do
    {:noreply, val + 1}
  end

  def handle_cast(:dec, val) do
    {:noreply, val - 1}
  end

  def handle_call(:val, _from, val) do
    {:reply, val, val}
  end
end
```

* Use `GenServer.cast` to send **asynchronous** `:inc` and `:dec` messages
    * notice they dont' send a return reply
* Use `GenServer.call` to send **synchronous** messages that return the state of the server
* Tweak the `start_link` to start a `GenServer`
    * Giving it the current module name and the counter
    * It invokes the `Rumbl.Counter.init`

```
$ iex -S mix

> alias Rumbl.Counter

> {:ok, counter} = Counter.start_link 10
{:ok, #PID<...>}

> Counter.dec counter
:ok

> Counter.dec counter
:ok

> Counter.val counter
8 
```
* OTP Counter server works exactly as before but we've gained much by moving it to a `GenServer`
    * no longer need to worry about setting up references for synchronous messages
        * taken care by `GenServer.call`
    * `GenServer` is now in control of the `receive` loop
        * allowing to provide features like code upgrading and handling of system messages

## Adding Failover

* OTP's benefits go beyond managing concurrent state and behavior
* OTP handles the linking and supervision of processes

### Supervision Strategies

* Able to restart each service the right way
    * ie. when database dies, want to automatically kills and restart the associated connection pool
* Policy decision should not impact code that uses the database
* In Phoenix, not too much code attempting to deal with the fallout for every possible exception
    * True the error reporting to log 
    * Automatically restart services in the last good state
* OTP captures the clean abstractions in a coherent library

With Supervision Tree with configuration policy, you can build **robust self-healing software** without building complex self-healing software.

* `rumbl.ex`

    ```
    children = [
      supervisor(Rumbl.Repo, []),
      supervisor(Rumbl.Endpoint, []),
      worker(Rumbl.Counter, [5])
    ]
    
    opts = [strategy: :one_for_one, name: Rumbl.Supervisor]
    ```

* **Child Spec** defines the children that an Elixir application will start
* `opts = [strategy: :one_for_one, name: Rumbl.Supervisor]`
    * set the policy for the application to use if something goes wrong
    * OTP calls this **supervision strategy**
    * In this case we are using `:one_for_one` strategy
        * it means when a child dies, only that child will be restarted
    * alternatively, `:one_for_all` strategy means kills all child process if any child dies

## Restart Strategies

* First Decision to make is to tell OTP what should happen if a process crashes
    * By default, child processes have `:permanent` restart strategy
        * always restared
* `:permanent` always restart
* `temporary` never restart
* `:transient` - restart only if it erminates **abnormally** with an exit reason other than
    * `:normal`, `:shutdown`, or `{:shutdown, term}`
* Options `max_restarts` and `max_seconds` are availble to retry a few times before failing
    * By default Elixir will allow **`3`restarts** in **`5` seconds**

## Supervision Strategies

* Just as child workers have different restart strategies, **supervisors** have configurable **supervision** strategires

* `:one_for_one`
    * If a child terminates a supervisor restarts only that process
* `:one_for_all`
    * If a child terminates, a supervisor terminates all children then restarts all children
* `:rest_for_one`
    * If a child terminates, a supervisor terminates all child processes defined **after** the one that dies, the supervisor restarts all terminated processes
* `:simple_one_for_one`
    * Similar to `:one_for_one` but used when a supervisor needs to dynamically supervise processes
    * ie. A web server would use to supervise web requests which may be 10, 1,000 or 100,000 concurrently running processes

## Using Agents

* Simpler abstraction with many of the benefits of a `GenServer` is call an **agent**
* With **Agent**, there are only **five** main functions
    * `start_link` to initialises the agent
    * `stop` to stop the agent
    * `update` to change the state of the agent
    * `get` to retrieve the agents' current value
    * `get_and_update` performs `get` and `update` simutaneously

    ```
    > import Agent
    nil
    
    > {:ok, agent } = start_link fn -> 5 end
    {:ok, #PID<...>}
    
    > update agent, &(&1 + 1)
    :ok
    
    > get agent, &(&1)
    6
    
    > stop agent
    :ok
    
    ```
## Registering Processes

* With OTP, we can register a process by name
* Named process can be either
    * **local** visible to a **single** node or
    * **global** visible to **all connected nodes**
* OTP provides registration by name with `:name` option in `start_link`

```
> import Agent

#
# MyAgent is not a string value
#
> {:ok, agent} = start_link fn -> 5 end, name: MyAgent

> get MyAgent, &(&1)
5
```

* If a process already exists with the registered named, we can't start the agent

## OTP and Channels

* If you are building a supervisor for a couple of application components, the default `:one_for_one` might be all we'd need
* Building channels as OTP application, **each** new channels was a process built to serve a single user in the context of a single conversation
* Much of the worlds' text messaging traffic runs on OTP infrastructure

## Designing an Information System with OTP

To enchnce the video annotations to another level with some OTP-backed information services

* For any request, inject highly relevant facts that we can inject
* Provide enhanced questionanswer-style annotations
* Pull inforamtion from an API like WolframAlpha whil referencing a local database
* Start multiple information system queries in parallel and accumulate the results
* Response with best matching

## Choosing a Supervision Strategy

Fetching the most relevant information for a user in real time across different backends

* Network or one of our thir0party services is likely to fail
    * since this operation is time sensitive; we want to spawn processes in parallel and let them do their work
    * We'll take as many results we can get
        * if one of ten of our information systems crashes, it is not a problem
    * so we'll use `:temporary` restart strategy


* `lib/rumbl/info_sys/supervisor.ex`

    ```
    defmodule Rumbl.InfoSys.Supervisor do
      use Supervisor
    
      def start_link() do
        Supervisor.start_link(__MODULE__, [], name: __MODULE__)
      end
    
      def init(_opts) do
        children = [
          worker(Rumbl.InfoSys, [], restart: :temporary)
        ]
        supervise children, strategy: :simple_one_for_one
      end
    end
    ```
    
    * `use Supervisor` to prepare our code to use the `Supervisor` API
    * `start_link` starts the supervisor
    * `init` is the function required by the contract that initializes our workers
    * Similiar to `GenServer.start_link`, `Supervisor.start_link` requires `init`    
    * Use `__MODULE__` compiler directive to pick up the current module's name
    * Use `__MODULE__` as the process name to allow reaching the supervisor instead of PID

    * Inside `init`,
        * call `supervise` to begin to supervise all of our workers
        * use `:simple_one_for_one` supervision strategy
* `lib/rumbl.ex` 

    ```
    children = [
        ...

      # new supervisor
      supervisor(Rumbl.InfoSys.Supervisor, [])
    ]
    ```
    * add the new supervisor to the application supervision tree
    * It ensures single crashes in an isolated information system won't impact the rest of the application
    * We've configure a supervisor that will in turn be supervised by the application

* Keep it in mind, it protected both directions;
    * Applications that crash will need to be restared and 
    * if Phoenix server crashes, we'll bring down all existing information systems and all other related services
        * so we don't have to worry about leaking resources

## Building a `start_link` proxy

* We've chosen a supervision strategy that allows to start children **dynamically**
* We'll like to be able to choose from server different backends
    * one for Google
    * one for WolframAlpha and etc

### User Flow

* User makes a query
* Our supervisor start up as many different queries as we have backends
* Collect the results from each
* Choose the best one to send to the user

### How can we create a single worker that knows how to start a variety of backends?

* Use a technique called **proxying**
    * a proxy function is lightweight function that stands between the original caller and the original implementation to do some simple task
* Our generic `start_ink` will proxy individual `start_link` functions for each of our backends

* `info_sys.ex`

    ```
    defmodule Rumbl.InfoSys do
    
      #
      # List of all backend we support
      #
      @backends [Rumbl.InfoSys.Wolfram]
    
      #
      # Define a struct to hold each search result
      #
      defmodule Result do
        defstruct score: 0, text: nil, url: nil, backend: nil
      end
    
      #
      # Our proxy - it calls a backend start_link
      # InfoSys is a :simple_one_for_one workder
      # whenever our supervisor calls Supervisor.start_child
      # for InfoSys, it invokes InfoSys.start_link 
      #
      # The function starts the backend
      #
      def start_link(backend, query, query_ref, owner, limit) do
        backend.start_link query, query_ref, owner, limit
      end
    
      #
      # Maps over all backends calling spawn_query for each
      # child giving options including a unique ref
      #
      def compute(query, opts \\ []) do
        limit = opts[:limit] || 10
        backends = opts[:backends] || @backends
    
        backends |> Enum.map(&spawn_query(&1, query, limit))
      end
    
      defp spawn_query(backend, query, limit) do
        query_ref = make_ref()
        opts = [backend, query, query_ref, self(), limit]
    
        {:ok, pid} = Supervisor.start_child(Rumbl.InfoSys.Supervisor, opts)
        {pid, query_ref}
      end
    end
    ```
    
## Building the Wolfram Info System

## Monitoring Processes

* Use `Process.monitor` to detch backend crashes while waiting on results

```
> pid = spawn(fn -> :ok end)
> Process.monitor(pid)
#Reference<...>

> flush()
{:DOWN, #Reference<0.0.7.564>, :process, #PID<0.577.0>, :noproc}

```
* `{:DOWN, ...}` informs that the process has died.

## Timing Out

* Every time we attempt to `receive` messages, we can use the `after` to specify a time in milliseconds

```
iex> recieve do
...>  :this_will_never_arrive -> :ok
...> after
...>   1_000 -> :timeout
...> end
:timeout

```
* we **could** use to specify a time out for every message but it has **hidden** problem
    * this approach is cumulative
    * ie. we change `receive` in `await_result` to use timeout of `5_000` milliseconds
        * If we have three information systems, it will be total of **5sec * 3** or 15 seconds
            * **Ray: Make no sense to me here???????**
    * Instead of using `after`, we'll use `Process.send_after` to send ourselfs a `:timeout` message

## Integrating OTP Services with Channels

* `$ mix run priv/repo/backend_seeds.exs` to seed database

## Wrapping Up

* Built a counter to demonstrates how some OTP behaviors work
* Looked at serveral OTP supervision and restart strategies
* Saw examples of a full OTP service as `GenServer`
* Learned how task wrap behavior and agents encapsulate state
* Implemented an information system abstract front end with concret backends
* Learned to fetch WolframAlpha results from an HTTP service and share with our channels
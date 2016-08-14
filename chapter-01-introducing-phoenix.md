# Chapter 1 - Introducing Phoenix

* Phoenix is a bout fast, concurrent, beautiful, interactive and reliable applications.
* Composing services with a series of functional transformations is reminiscent of *Clojure's Ring*

## Fast

* Elixir is both fast and concurrent as expected from running on the Erlang virtual machine
* [https://github.com/mroth/phoenix-showdown/blob/master/README.md](https://github.com/mroth/phoenix-showdown/blob/master/README.md)
* [Comparative Benchmark Numbers @ Rackspace](https://gist.github.com/omnibs/e5e72b31e6bd25caf39a)

> *Throughput* is the total number of transactions
> *Latency* is the total waiting time between transactions
> *consistency* is a satistical measurement of the consistency of the response

* Phoenix is the fastest framework in the benchmark and among the most consistent.
    * the slowest request won't be that much slower than the fastest due to Elixir's lightweight concurrency.
        * Elixir garbage collector works at the invidual process level - not the stop the world app level
* *WhatsApp* achieved two million concurrently running connections on a single node
* The router compiles down to the cat-quick pattern matching
* Templates are precompiled
    * Phoenix doesn't need to copy strings - caching come into play at the hardware level
* Functional languages do better on the web

## Concurrent

* Multicore architectures is coming
    * Existing imperative modesl won't scale to handle to run on hardware with thousands of cores
* Languages like *Java* *C#* place the ubrden of managing on the shoulders of the programmer
* Languages like *PHP* and *Ruby* make threading difficult
    * many developers try to support only one web connection per operating-system process or some structure marginally better

> `PhoenixDelayedJob` o r`ElixirResque` complex packages that exist only to spin off reliable
> processes as a separate web task

* When you have two database fetches, you won't have to artificially batch them together

## Beautiful Code

* Elixir is the first functional language to support Lisp-style macros

## Simple Abstractions

* One continuous problem with Web Frameworks is that they tend to bloat over time - sometime fatally
* Especially with OO Languages
    * Inheritances is simply not a rich enouch abstractions to the endtire web platform
    * ie. Think about Authentication
        * Impacts every layers
        * Database models must be aware
            * authentication schemes
        * Controllers are not immune
            * Signed-in user must be treated differently than those who are not
        * View Layers
            * the contents must change based on whethere a user is signed in or not

## Effortlessly Extensible

Rather than rely on other mechanisms like *inheritance* that hide intensions, roll up new functions into explicit list called *pipelines*

## Interactive

A traditional web stack makes it hard to create interactive applications.

* Before web, client-server applications were simple
    * a client process or two communicated to its own process on the server
    * But hard to scale - each application connection required 
        * its own resources
            * operating-system process
            * a network connection
            * a database connection
            * its own memory
        * hardware didn't have enough resources to do that work efficiently
        * languages couldn't support many processes

## Scaling by Forgetting

Traditional web servers solve the scalability problem by treating all user interaction as an identical request

* One type of connection
    * Application doesn't save the state
    * Simply look up the user and the user session

## Processes and Channels

* With Elixir, you can have both performance and productivity
    * *lightweight processes* over *operating system process*
    * *connections* can be *conversations*
    * typical channels like

    ```
    def handle_in("new_annotation", params, socket) do
      broadcast! socket, "new_annotation", %{        user: %{username: "anon"},
        body: params["body"],        at: params["at"]      }      {:reply, :ok, socket}    end
    ```
* Other frameworks can also give channel-style features but
    * none can gurantee isolation cand concurrency like Phoenix
*  If a bug affects one channel, all other channels continue running
    *  breaking one feature won't bleed into other site

## Reliable

* Erlang has alwasy been more reliable
    * process linking structure and the process communication with effective supervision
    * supervisor can have supervisors too - a tree of supervisors
* Phoenix has setup most of the supervision structure
    * ie. Talking to database, a pool of DB connections is supervised out of the box
* Phoenix has solved the hard problems out of the box.
[https://pragprog.com/book/phoenix/programming-phoenix](https://pragprog.com/book/phoenix/programming-phoenix)

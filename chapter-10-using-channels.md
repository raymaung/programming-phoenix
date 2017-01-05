# Chapter 10 - Using Channels

Since Elixir can scale to millions of simultaneous processes that manage
millions of concurrent connections, it is no longer required to resort to
*request/response* to make things easy to scale or even manage.


## The Channel

* A Phoenix channel is a conversation.
    * The chnnnels sends messages/receives messsages and keep state
* We call the messages *events* - put the state in a struct called `socket`



### *topic*

* A Phoenix conversation is a bout a *topic* and maps onto application
concepts like a chat
* More than one user might be interested in the same topic at the same time
* *Channels* gives tools to organize the code and the communication among users
* *Each user's conversation on a topic has its own isolated*

* *request/response* are *stateless* whereas,
    * conversation in a long running process can be *stateful*.
    * no need for *cookies*, *databases* or the like to keep track of the conversation.


* The approach only works if the foundation gurantees
    * true isolation
        * one crashing process won't imact other subscribed users
    * true concurrency
        * Lightweight abstractions the won't bleed into one another

Your chaannels application will have to worry about three things

* Making and breaking connections
* Sending messages
* Receiving messages

## Phoenix Clients with ES6

```
>  npm install --save-dev babel-preset-es2016

> node_modules/brunch/bin/brunch build

> node_modules/brunch/bin/brunch build --production
 
> node_modules/brunch/bin/brunch watch
```

## Preparing Our Server for the Channel

* In the request/response world,
    * each request established a connection represented by `Plug.Conn`
    * Ordinary functions to transform that connection until the response
* In channels, the flow is different
    * A client establishes a new connection with a `socket`
    * After the connection is made, that socket will be transformed through the life of the connection

> At the high level, `socket` is the ongoing conversation between client and server
> it has all of the information necessary to do its job.

* When you make a connection
    * you are creating your initial `socket`
    * the same socket will be transformed with each received event through the whole life of the whole conversation.

### To Make a connection

* Decide whether to allow the connection
* Create the initial `socket`
    * including any custom application setup your application might need

## Preparing Our Server for the Channel

* `web/static/js/socket.js`

    ```
    import {Socket} from "phoenix"    let socket = new Socket("/socket", {
      params: {token: window.userToken},      logger: (kind, msg, data) => {
        console.log(`${kind}: ${msg}`, data)
      }    })    export default socket
    ```

    * import `Socket` object
    * `let socket = new Socket("/socket",...` causes Phoenix to instantiate a new socket at our end point

* `lib/rumbl/endpoint.ex`

    ```
    socket "/socket", Rumbl.UserSocket
    ```
    
    * `Rumbl.UserSocket` serves as the starting point for al socket connections
        * responsible for authenticating
        * responsible for wiring up default socket information for all channels

* `web/channels/user_socket.ex`

    ```
    defmodule Rumbl.UserSocket do
      use Phoenix.Socket

      # Transports
      transport :websocket, Phoenix.Transports.WebSocket
      # transport :longpoll, Phoenix.Transports.LongPoll

     def connect(_params, socket) do
      {:ok, socket}
     end

     def id(_socket), do: nil 
     end

    ```
    
    * `UserSocket` uses a single connection to the server to handle all your channel processes
    * Defines the transport layers to handle the connection between your client and the server

    * Phoenix supports two default transport protocols
        * You can build your own
        * Regardless of the transport, the end result is the same
        * `socket` abstract away the transport protocols
        * No need to worry user connections
            * Long-polling for older browser
            * Native iOS WebSockets
            * Custom transport like CoAP for embedded devices
        * Backend channels code remains precisely the same

    * `UserSocket` have two simple functions `connect` and `id`
        * `id` function identifies the socket based on some state stored in the socket itself
            * ie. UserId
        * `connect` decides whether to make a connection
        * In our case, `id` returns `nil` and `connect` lets everyone in

## Creating the Channel

* Review
    * a channel is a conversation on a topic
    * Our topic has an identifier of `videos:video_id`
        * `video_id` is a dynamic ID matching a record in database
* *topics* are strings that serve as identifiers
    * they take the form of `topic:subtopic`
        * `topic` is often a resource name
        * `subtopic` is often an ID

> Since topics are organizing concepts, we'll include where you'd expect
> as parameters to functions and in our URLs to idenfity conversations.
> 
> Just as the client passes a URL with an `:id` to represent a resource
> for a controller, we'll provide a topic ID to scope our channel
> connections

## Joining a Channel

Once a socket connection is established, the users can join a channel. In
general, when clients join a channel, they must provide a topic. They 
can join any number of *channels* and any number of *topics* on a channel.

* `web/channels/user_socket.ex`

    ```
    defmodule Rumbl.UserSocket do
      use Phoenix.Socket

    ## Channels
    channel "videos:*", Rumbl.VideoChannel
    ...
    ```
    
    * Transports route events into your `UserSocket`
    * Then they are dispatched into your channels based on topic patterns
        * declared with `channel` macro
    * `videos:*` convention categorizes topics with a resource name followed by a resource ID

## Building the channel Module

* Module to handle specific `Video` channel, 
    * it will allow connections through `join`
    * let users disconnect
    * send events

> For consistency with OTP naming conventions, the book refers
> these features as *callbacks*

* `web/channels/vide_channel.ex`

    ```
    defmodule Rumbl.VideoChannel do
      use Rumbl.Web, :channel

      def join("video:" <> video_id, _params, socket) do
        {:ok, assign(socket, :video_id, String.to_integer(video_id))}
      end
    end
    ```
    
    * `{:ok, socket}` to authorize a `join` or `{:error, socket}` to deny one
    * Add the video ID to `socket.assign

    > Remember: sockets will hold all the state for a given conversation
    > Each socket can hold its own state in the `socket.assigns` field
    > typically holds a map
    
> For channels, *the socket* is transformed in a loop rather than a single pipeline
> In fact the socket state will remain for the duration of a connection. That
> means the socket state we add in `join` will be accessible later as
> events come into and out of the channel.
> 
> This small distinction leads to an enormous difference in efficiency between the 
> channelss API and the controllers API

* `web/static/js/video.js`

    ```
    onReady(videoId, socket) {
    
      let msgContainer = document.getElementById("msg-container")
      let msgInput = document.getElementById("msg-input")
      let msgButton = document.getElementById("msg-submit")

      let vidChannel = socket.channel("videos:" + videoId)

      vidChannel.join()
        .receive("ok", resp => console.log("joined the video channel", resp))
        .receive("error", resp => console.log("joined failed", resp))
    }
    ```
    
    * Create a new channel object `vidChannel` from `socket` with `"videos:" + videoId`

## Sending and Receiving Events

* Just as controllers receive requests, channels receive events
* With channels, we receive a message containing an event name
    * ie. `new_message` and a layload of arbitrary data
* Each channel module has three ways to receive events
    * `handle_in` receives direct channel events
    * `handle_out` intercepts broadcast events
    * `handle_info` receives OTP messages

### `handle_info`

```
  def handle_info(:ping, socket) do
    count = socket.assigns[:count] || 1
    push socket, "ping", %{count: count}

    {:noreply, assign(socket, :count, count + 1)}
  end
```

* `handle_info` is invoked whenever an Elixir message reaches the channel
    * ie. we match on the periodic `:ping` message and increase a counter
    * `:noreply` means we're not sending a reply
    * `assign` transforms our socke by adding the new count
    * Conceptually, we are taking a socket and returning a transformed socket.

* `handle_info` is essentially a loop
    * each time, it returns the socket as the last tuple element for all callbacks
        * this way we can maintain a state
    * `push` the `ping` event
        * the client picks up these events with the `channel.on(event, callback)` API

This is the primary difference between channels and controllers. Controllers process a *request*, Channels hold a *conversation*.

## Annotating Videos

### Adding Anotations on the Server

* Forwarding a **raw** message payload without inspection is a big security risk

    ```
    broadcast! socket, "new_annotation", Map.put(params, "user", %{
        username: "anon"    })
    ```
* Without properly structure the payload from the remote client before forwarding, we are allowing a client to broadcast arbitrary payloads across the channel

## Persisting Annotations

* When the insert is success, broadcast to all subscribers as before.
* Send a reply `{:reply, :ok, socket}` as common practice to acknowledge
    * may decide not to send a reply with `{:noreply, socket}`

## Handling Disconnects

* Any stateful conversation between a client and serve must handle data that gets out of sync
    * unexpected disconnect
    * broadcast that isn't received

### On the Java Script Client

Can be disconnected and reconnected for many reasons

* Server restared
* Poor Internet connection
* Can't assume network reliability

Potential Solutions:

* Temped to have the **client** handle duplications;
    * required ignoring and filtering duplicates
* Better solution is to track `last_seen_id`
    * reduced data required from the server
    * keeps us from worrying about buffering messages on the server for the clients that might never reconnect
    * Use `vidChannel.params` (`Socket` object);
        * `params` is send to the server on `join`

## Wrapping Up

* Learn to connect a server side channel through an ES6 client
* Built a server side channel with both long-polling and WebSocket support
* Built a simple API to let user join a channel
* Process inbound messages from OTP with `handle_info` and channels with `handle_in`
* Sent broadcast messages with `boradcast!`
* Authenticated users with `Phoenix.Token`
* Persisted annotations with Ecto
* 
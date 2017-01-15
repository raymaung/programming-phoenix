# Chapter 14 - What's Next?

* First, we built a toy application
    * router talbe
    * connection flow through plugs
    * controllers
    * view to rnder a template
* `rumbl` application
    * controller
    * simple repository stub
    * actions and views and templates
    * replace in-memory stub
    * use `ecto` with a full database-backed repository
    * migration and changeset to manage changes
    * used the models in the controller
    * create a plug to integrate authentication
    * more complex models with relationships
    * test
* Built a channel to handle real-time features
    * learned the Phoenix messaging to build applications with state
    * paired with an ES6 JavaScript client
    * used channels to let user post/broadcast messages
    * extend authentication system
* Crafted an Information System Service as OTP
    * concurrency
    * message passing
    * recursive functions
    * supervisors
* Extracted into an umbrella application
    * used **Observer** to get a full picture of what was happening in real time
    * Isolate development and testing individual units
    * tested the channels and OTP services

## Other Interesting Features

### Supporting Internationalization with Gettext

* In version `v1.1`, Phoenix added **Gettext**
    * Internationalization and localization system
    * when you ran `mix phoenix.new rumbl`
        * `Rumble.Gettext` is generated at `web/gettext.ex`
        * usage in `web/views/error_helpers.ex`
        * Translations for different languages in `priv/gettext`
        * `errors.pot` a default template for Ecto messages
    * [Internationalization using Gettext in the Phoenix framework](http://sevenseacat.net/2015/12/20/i18n-in-phoenix-apps.html)

## Intercepting on Phoenix Channels

* When you broadcast a message, Phoenix sends it to the Publish and Subscribe (PubSub) system
    * PubSub broadcast directly to all user sockets
        * aka **Fastlaning** it completly bypasses the channel;
            * alloing us to encode the message **once**
    * Phoenix **also** provides `intercept`
        * allow channels to intercept a broadcast message before sending to the user


```
intercept ["new_annotation"]# For every new_annotation broadcast,# append an is_editable value for client metadata.

def handle_out("new_annotation", msg, socket) do  %{video: video, user_id: user_id} = socket.assigns
  push socket, "new_annotation",  Map.merge(msg, %{is_editable: video.user_id == user_id})
  {:noreply, socket}end
```

* For each event specify in `intercept`,
    * we must define a `handle_out` to handle the intercepted event in case you want to make sure that some clients don't receive specific events

* `intercept` is a nice feature **but**
    * if you have 10,000 users at the same time
        * then you may want to just include in the message instead of `intercept`
        * For example, Phoenix sends the message to 10,000 channnels processes\
            * each channels would have to process `intercept` independently to generate
                * 10,000 messages and encoding those messages 9,999 times
                    * one per channel - instead of the one-time encoding of the implementation


* `intercept` is useful when evolving code
    * ie. Build a new version of annotation
        * Old clients taking a while to migrate
        * you could use the new annotation braodcast format through the new code
            * Use `intercept` to retrofit the new annotation to broadcast into the old one

## Understanding Phoenix Live Reload

Composed of 

* `fs` dependency to watch the file system
* A channel that receives events from the `fs` and converts them into broadcasts
* A plug that injects the live-reload iframe on every request and serves the iframe content for web requests


## Phoenix PubSub Adapter

* By default Phoenix PubSub uses Distributed Erlang
    * to ensure that boradcasts work across multiple nodes
    * require all machines to be connected together according to the Erlang Distribution Protocol
    * may not be supported in some deployment platforms

* Phoenix PubSub is extensible; supports multiple adapters
    * one is Redis adapter - maintained by Phoenix team

## Phoenix Clients for Other Platforms

* In our channels, we customised the Phoenix transport to work with our ES6 code
* Phoenix channels supprts Javascript and also a wide range of other clients and platforms
    * including C#, Java, Objective-C and Swift
* the clients uses WebSockets and Phoenix Channels are transport **agnostic**
* Also expect to see ELM to show up

## Casting Ecto Associations

* We've covered all the main Ecto concepts
    * from repositories, queires and changesets
    * some associations
* But we didn't cover the ability to cast/change an association at the same time that we modify its parent model
    * it allows developer to build different form sections for each associated records
    * [Working with Ecto associations and embeds](http://blog.plataformatec.com.br/2015/08/working-with-ecto-associations-and-embeds/)

## What's Coming Next

### Ecto 2.0

* Support for `many_to_many` associations easier
* Support for concurrent transactional tests
    * Ecto v2.0 to ship with an ownership based mechanism
        * to allow even tests with side-effects to run concurrently
* Support for `insert_all` to allow batch inserts
    * currently suport for `update_all` and `delete_all`

## Phoenix Presence

* Phoenix presence to allow developers to track which users are connected to which channel
    * built on top of PubSub allowing to run clusters of Phoenix applications
        * without needing to configure extra dependencies like Redis

## Phoenix Components

* GraphQL - No plan to integrate directly into Phoenix
    * will make real-time Phoenix applications simpler

* One idea is GraphQL template with the data it needs all in the same place
    * developers provide components which combine templates with a specification for the data it requires
    * Phoenix automatically cache templates and provide real-teim updates based on the true state of the data
        * allowing Phoenix to automatically push data to clients whenever a record is added or removed

## Good Luck

    
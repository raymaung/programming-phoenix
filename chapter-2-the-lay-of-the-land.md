# Chapter 2 - The Lay of the Land

## Simple Functions

```
def inc(x), do: x + 1
def dec(x), do: x - 1

2 |> inc |> inc |> dec

```

* `|>` pipes or pipelines
* each individual function is called *segment* or *pipe sigment*

## The Layers of Phoenix

```
connection
    |> endpoint
    |> router
    |> pipelines
    |> controller
    
```

* Each request comes in through an `endpoint` - the first point of contact
    * Literally the end or the beginning of the Phoenix world
* Request goes through `router` layer
* Direct a request into the appropriate `controller` after passing through a series of `pipelines` 

## Inside Controller

* *Smalltalk* introduced a *model-view-controller* (MVC)
    * Models access data
    * View present data
    * Controllers coordinate between the two

```
connection
    |> controller
    |> common_services
    |> action
```

* Connection flow into the controller
* Calls common services
    * implemented with *Plug*
    * Think of *Plug* as a strategy

    ```
    connection
        |> find_user
        |> view
        |> template
    ```

## Installing Your Development Environment

* Elixir Needs Erlang
* Phoenix Needs Elixir

```
> elixir -v
Elixir 1.1.0
```

* Install *Hex*

    ```
    > mix local.hex
    ```

* Ecto Needs PostgreSQL

    ```
    > psql --version
    psql (PostgreSQL) 9.2.1
    ```

* Node.js For Assets

    ```
    > node --version
    v5.3.0
    ```
* Phoenix

    ```
    > mix archive.install https://github.com/phoenixframework/archives/raw/master/phoenix_new.ez
    ```

## Creating a Throwaway Project

```
> mix phoenix.new hello
> cd hello
> mix ecto.create
> mix phoenix.server

# To run in IEX mode
> iex -S mix phoenix.server
```

## Building Features

* All requests start at `web/router.ex`

    ```
    scope "/", Hello do
      pipe_through :browser # Use the default browser stack

      get "/", PageController, :index
    end
    ```

    * `:pipe_through :browser` macro handles some house keeping for all common browser-style requests
    * Send `/` url to the `:index` action of `PageController`

### Adding Page

* Add a route in `router.ex`
    * `get "/hello", HelloController, :world`
* Add a controller and action - `HelloController` and `world`
* Add view - `hello_view.ex`
* Add template `hello/world.html.eex`

## Using Routes and Params

```
  def world(conn, %{"name" => name}) do
    render conn, "world.html", name: name
  end
```

* Pattern match inbound parameters in action

> `world` action external parameters have *string* keys `"name" => name`
> but `name: name` is used internally because Phoenix can't gurantee
> external data can be safely converted to atoms.

## Using Assigns in Templates

```<h1>Hello <%= String.capitalize @name %>!</h1>
```

* `<%= %>` to suibstitue into the rendred page 
* `@name` has the value of `:name` passed to `render`

## Going Deeper: The Request Pipeline

> Typical web applications are just a big functions -
> Each web request *URL* is a function call in a single formatted string
> and the function returns another formatted string.

* Phoenix encourages breaking a big functions down int osmaller ones
* Provides a place to explicitly register each smaller functions
* All tige together with the *Plug* library.

### Plug Library

* A specification for building applications that connect to the web
* Each plug consumes and produces a common data structure called `Plug.Conn`
    * `Plug.Conn`  represents *the whole universe for a given request*
* Words like *request* and *response* does **NOT** mean a request is a function call and a response is a return value
    * A response is just one more action on the `connection`

    ```
    conn
        |> ...
        |> render_response
    ```
    
> The whole phoenix framework is made up of organizing functions that do 
> something to connections, even *rendering the result*

> Plugs are functions
> Your web applications are pipelines of plugs

## Phoenix File Structure

```
...├── config
├── lib
├── test
├── web
...
```

* `config` Phoenix configuration
* `lib` Supervision trees and long-running processes
* `test` Tests
* `web` All web related codes - models, views, templates and controllers

> When reloading turn on, the code in `web` is reloaded, and
> the code in `lib` isn't
> 
> `lib` is the perfect place to put long-running
> services like Phoenix's PubSub system, the database
> connection pool or your own wupervised processed.

## Elixir Configuration

* Phoenix projects are Elixir applications
    * they have the same structure as other Mix projects

```
...├── lib│ ├── hello│ │ ├── endpoint.ex│ │ └── ...│ └── hello.ex 
├── mix.exs├── mix.lock
├── test...
```

* `.ex` files are compiled to `.beam` files
* `.exs` files are Elixir's scripts
    * not compiled into `.beam` files
* Each project has a configuration file `mix.exs`
    * basic project information
        * compiling files
        * starting the server
        * managing dependencies
    * `mix.lock` - include the specific versions of the libraries
* `lib` support for starting, stopping and supervising each application `lib/hello.ex`  
* `test` test folder

## Environments and Endpoints

```
...├── config│ ├── config.exs│ ├── dev.exs│ ├── prod.exs│ ├── prod.secret.exs│ └── test.exs ...
```

* `config.exs` a master configuration file
* Other files are for each environment
* Default to `dev.exs`
* `prod.secret.exs` contains secret production passwords
    * Keep out of version control
* Switching between different environment via the `MIX_ENV` environment variable


```
# Configures the endpoint
config :hello, Hello.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "0ZMnYThS35jbbWP+7pteZ7H8jwb+KyH7cWy890ru5+Dgzkfoosk79+5rFdcE1ach",
  render_errors: [view: Hello.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Hello.PubSub,
           adapter: Phoenix.PubSub.PG2]

```
* `config.exs`
    * Logging
    * Endpoints
        * End point is where the web server lands off the connection to the application code
    * Contains a single end point initially `Hello.Endpoint`
* `Hello.Endpoint` defined in `lib/hello/endpoint.ex`

```
defmodule Hello.Endpoint do  use Phoenix.Endpoint, otp_app: :hello  plug Plug.Static, ...  plug Plug.RequestId  plug Plug.Logger  plug Plug.Parsers, ...  plug Plug.MethodOverride  plug Plug.Head  plug Plug.Session, ...  plug Hello.Routerend
```
* a chain of functions or *plugs* - can be read as

    ```
    connection        |> Plug.Static.call        |> Plug.RequestId.call        |> Plug.Logger.call        |> Plug.Parsers.call        |> Plug.MethodOverride.call        |> Plug.Head.call        |> Plug.Session.call        |> Hello.Router.call
    ```

```
connection  |> endpoint  |> plug  |> plug  ...  |> router  |> HelloController
```
An end point is a plug - one that's made up of other plugs. Your appplication is a series of plugs, beginning with an end point and ending with a controller.

> Although applications usually have a single end point, Phoenix doesn't limit 
> the number of end points: app end point at *port 80 HTTP*, *port 443 SSH*, *port 8080 HTTPS*.
> 
> Multiple endpoints should be broken down using *umbrella projects*

## The Router Flow

* `web/router.ex`

    ```
      pipeline :browser do
        plug :accepts, ["html"]
        plug :fetch_session
        plug :fetch_flash
        plug :protect_from_forgery
        plug :put_secure_browser_headers
      end
    
      pipeline :api do
        plug :accepts, ["json"]
      end
    ```
* Made up of two parts *pipelines* and *a route table*
    * To perform a common set of tasks or transformations for some logical group of functions
    * *pipeline* is just a bigger plug that takes `conn` and returns `conn`
* By default there are two `pipeline` defined `:browser` and `:api`

```
  scope "/", Hello do
    pipe_through :browser # Use the default browser stack

    get "/hello/:name", HelloController, :world
    get "/", PageController, :index
  end 
```

* All of the routes after `pipe_through :browser` go through the browser pipe line then the router triggers the controller

In general, the router is the last plug in the endpoint, every traditional Phoenix application looks like this.

```
connection    |> endpoint    |> router    |> pipeline    |> controller
```

* The endpoint has functions that happen for every request
* The connection goes through a named pipe line - which has common functions for each major type of request
* The controller invokes the model and renders a template through a view

## Controllers, Views, and Templates

* Conroller is the gateway for the bulk of a traditional web application
    * making data available in the connection for consumption by the view
    * potentially, fetch database data to stash in the connection
        * then redirects or renders a view
* Views substitutes values for a template

* `router.ex` tells Phoenix what to do with each inbound request
* `web.ex` contains some blue code that defines the overall application structure

```
...└── web   ├── channels   ├── controllers   │    ├── page_controller.ex    │    └── hello_controller.ex   ├── models   ├── static   ├── templates
   │    ├── hello   │    │   └── world.html.eex
   │    ├── layout
   │    │   └── app.html.eex   │    ├── page    │    │   └── index.html.eex   ├── views
   │    ├── error_view.ex 
   │    ├── layout_view.ex
   │    ├── page_view.ex
   │    └── hello_view.ex   ├── router.ex   └── web.ex
```

* `web` contains directories for models, views, and controllers
* `templates` directories - Phoenix seprates the views from the templates themselves
* `static` a directory for static content


Phoenix handles plenty of production-level concerns
* the Erlang virtual machine and OTP engine will help the application scale
* the endpoint will filter out static requests and also parse the request into pieces and trigger the router
* the browser pipeline will honor `Accept` headers, fetch the session and protect from attacks like *Cross-Site Request Forgery (CSRF)*

```
connection               # Plug.Conn|> endpoint              # lib/hello/endpoint.ex|> browser               # web/router.ex|> HelloController.world # web/controllers/hello_controller.ex
|> HelloView.render(     # web/views/hello_view.ex           "world.html") # web/templates/hello/world.html.eex
```
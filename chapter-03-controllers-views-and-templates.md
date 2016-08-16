# Chapter 3 - Controllers, Views and Templates

## The Controller

* Controller actions can do many different kinds of tasks
    * ie. connecting to some kind of data source
    * another web site
    * dataase

## Creating the Project 

```
> mix phoenix.new rumbl

Fetch and install dependencies? [Yn] y* running mix deps.get* running npm install && node node_modules/brunch/bin/brunch build

We are all set! Run your Phoenix application:    $ cd rumbl    $ mix phoenix.serverYou can also run your app inside IEx:    $ iex -S mix phoenix.serverBefore moving on, configure your database in `config/dev.exs` and run:    $ mix ecto.create
```

## A Simple Home Page

## Creating Some Users

## Elixir Structs

* Built on top of maps

> `iex -S mix` to start an interactive Elixir

```
> jose = %User{name: "Jose Valim"}%User{id: nil, name: "Jose Valim", username: nil, password: nil}

> jose.name
"Jose Valim"

> jose.__struct__
Rumbl.User
```

## Working with Repositories

* Add in-memory repo in `lib/rumbl/repo.ex`

```
> alias Rumbl.User
> alias Rumbl.Repo
> Repo.all User
[ %Rumbl.User{...},
...
]

> Repo.all User
[ %Rumbl.User{...}
...
]

> Repo.get User, "1"
%Rumbl.User{id: ...}

> Repo.get_by User, name: "Bruce"
```

## Building a Controller

* `/web/controllers/user_controller.ex`

    ```
    defmodule Rumbl.UserController do
      use Rumbl.Web, :controller      def index(conn, _params) do        users = Repo.all(Rumbl.User)        render conn, "index.html", users: users      end
    end
    ```

## Coding Views

In Phoenix
* *View* are modules responsible for rendering
* *Templates* are web pages/fragments that allow both static and native code to build response pages

> A *view* is a module containing rendering functions that convert
> data into a format the end user will consume - like *HTML* or *JSON*

> A *template* is a function on that module, compiled from a file
> containing a raw markup language and embedded Elixir code to process
> substitutions and loopss.

## Using Helps

```
> iex -S mix

> Phoenix.HTML.Link.link("Home", to: "/")
{:safe, ["<a href=\"/\">", "Home", "</a>"]}

> Phoenix.HTML.Link.link("Delete", to: "/", method: "delete")
{:safe,
  [["<form action=\"/\" class=\"link\" method=\"post\">",   "<input name=\"_method\" type=\"hidden\" value=\"delete\">    <input name=\"_csrf_token\" type=\"hidden\" value=\"UhdjBFUcOh...\">"],   ["<a data-submit=\"parent\" href=\"#\">", "[x]", "</a>"], "</form>"]
}
```

* `link` is a keyword list with `to:` specifying the target

## Naming Conventions

* Phoenix infers the name of the *view* module `Rumbl.UserView` from the controller module `Rumbl.UserController`

## Nesting Templates

```
> user = Rumbl.Repo.get Rumbl.User, "1"
%Rumbl.User{..}

> view = Rumbl.UserView.render("user.html", user: user)
{:safe, [[[[["" | "<b>"] | "José"] | "</b> ("] | "1"] | ")"]}

> Phoenix.HTML.safe_to_string(view)
"<b>José</b> (1)"

```

## Layouts

```
      <p class="alert alert-info" role="alert"><%= get_flash(@conn, :info) %></p>
      <p class="alert alert-danger" role="alert"><%= get_flash(@conn, :error) %></p>

      <main role="main">
        <%= render @view_module, @view_template, assigns %>
      </main>

    </div> <!-- /container -->
    <script src="<%= static_path(@conn, "/js/app.js") %>"></script>
```

* `render @view_module, @view_template, assigns`
* `@conn` is also available in the layout
* When you call `render` in the controller, `:layout` option is set by default
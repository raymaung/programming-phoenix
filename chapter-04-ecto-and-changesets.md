# Chapter 04 - Ecto and Changesets

## Understanding Ecto

* Ecto is a wrapper intended for rational databases
* *changeset* holds all changes to perform on the database
    * encapsulates the process of receiving external data
    * casting
    * validating before writting to the database

### Steps

* `lib/rumbl/repo.ex` set Repo to use Ecto
* `lib/rumbl.ex` Enable `supervisor` to the `Repo`
* `config/dev.exs` configure database

## Defining the User Schema and Migration

* `schema` and `field` macros to specify database table and Elixir structure
* After `schema`, Ecto defines `%Rumbl.User{...}`

* `mix ecto.gen.migration create_user` to generate migration script

    ```
    defmodule Rumbl.Repo.Migrations.CreateUser do
      use Ecto.Migration
    
      def change do
        create table(:users) do
          add :name, :string
          add :username, :string, null: false
          add :password_hash, :string
    
          timestamps
        end
    
        create unique_index(:users, [:username])
      end
    end
    ```
* `mix ecto.migrate` to migrate to the *current* environment

## Using the Repository to add Data

```
> iex -S mix

> alias Rumbl.Repo

> Repo.insert(%User{name: "José", username: "josevalim", password_hash: "<3<3elixir"})

> Repo.insert(%User{name: "Bruce", username: "redrapids", password_hash: "7langs"})

> Repo.insert(%User{name: "Chris", username: "cmccord", password_hash: "phoenix"})

> Repo.all(User)
> Repo.get(User, 1)
```

## Building Forms

* `controllers/user_controller.ex`

    ```
    alias Rumbl.User    
    def new(conn, _params) do      changeset = User.changeset(%User{})      render conn, "new.html", changeset: changeset    end
    ```
    
    * Changesets let Ecto manage record
        * changes
        * cast parameters
        * perform validations

* `models/user.ex`

    ```
    def changeset(model, params \\ :empty) do
      model
        |> cast(params, ~w(name, username), [])
        |> validate_length(:username, min: 1, max: 2)
    end
    ```
    
    * Accepts a `User` struct and parameters
    * `cast` to tell Ecto that `name` and `username` are required
        * `cast` make sure all required and options values to their schema types
        * rejecting everything else
    * `params \\ : empty` default to distinguish between a blank form submission and an empty map

    > Convention persistence frameworks allow *one-size-fits-all* validations; forced work
    > harder and manage change across multiple concerns.
    >
    > *One size does not fit all* when it comes to update strategies. Validations, error
    > reporting and security and the like can change. When they change, the single update
    > policy is tightly coupled to a schema.
    >
    > Ecto change set decouple update policy from the schema.

* `web/router.ex`

    ```
    scope "/", Rumbl do
      pipe_through :browser # Use the default browser stack

      get "/", PageController, :index
      resources "/users", UserController, only: [:index, :show, :new, :create]
    end
    ```

    * `resources` is a shorthand to implement a common set of REST actions

        ```
        get "/users", UserController, :index        get "/users/:id/edit", UserController, :edit get "/users/new", UserController, :new        get "/users/:id", UserController, :show        post "/users", UserController, :create        patch "/users/:id", UserController, :update
        put "/users/:id", UserController, :update
        delete "/users/:id", UserController, :delete
        ```
        
        * `mix phoenix.routes` to view the routes


### How does Phoenix know which data to show in the form?

To avoid `form_for` coupling to `Ecto.Changeset`, Phoenix defines `Phoenix.HTML.FormData`

## Creating Resources

```
  def create(conn, %{"user" => user_params}) do
    changeset = User.changeset(%User{}, user_params)
    {:ok, user} = Repo.insert(changeset)

    conn
      |> put_flash(:info, "#{user.name} created!")
      |> redirect(to: user_path(conn, :index))
  end

```

### Handling Error

```
def create(conn, %{"user" => user_params}) do
  changeset = User.changeset(%User{}, user_params)

  case Repo.insert(changeset) do
    {:ok, user} ->
      conn
        |> put_flash(:info, "#{user.name} created!")
        |> redirect(to: user_path(conn, :index))

    {:error, changeset} ->
      render(conn, "new.html", changeset: changeset)
  end
end
```

```
<%= if @changeset.action do %>
    <div class="alert alert-danger">
      <p>Oops, something went wrong! Please check the errors below</p>
    </div>
<%= end %>
```
  
* `@changeset.action` indicates an action we tried to perform on it ie. `:insert`
    * default is `nil`


```
iex> changeset = Rumbl.User.changeset(%Rumbl.User{username: "eric"})
%Ecto.Changeset{changes: %{}, ...}

iex> import Ecto.Changeset
nil

iex> changeset = put_change(changeset, :username, "ericmj") %Ecto.Changeset{changes: %{username: "ericmj"}, ...}
iex> changeset.changes
%{username: "ericmj"}iex> get_change(changeset, :username)
"ericmj"
```

Ecto is using *changesets* as a bucket to hold everything related to a database change before and after persistence.

More can be done than see what changed

* Write code to do the minimal required database operation to update a record
* Enforce validations without hitting the database; you can do the same too

## Wrapping Up

* Replaced the in-memory repository with a database-backed repository using Ecto
* Configure a new database and connected it to OTP; Elixir could do the right thing in the event of a Phoenix or Ecto crash
* Created a schema and complete with information
* Created a migration
* Created a changeset
* Integrated into the application


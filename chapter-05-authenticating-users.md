# Chapter 05 - Authenticating Users

## Preparing for Authentication

* Authentication is a feature that can make or break the whole application experience
* Programmers need to be able to easily layer on the right services and direct requests
* Administrators need to trust the underlying policies

* `mix.ex`

    ```
    defp deps do
      [...,        {:comeonin, "~> 2.0"}]
    end
    
    def application do
      [mod: {Rumbl, []},
        applications [...,
          :comeonin]]
    end
    ```
    
    * Add `:comeonin` as dependencies
    * Think an `application` as a collection of modules that work together
        * handle critical services, ie
            * `:phoenix`
            * `:phoenix_ecto`
            * `:logger`
            * etc.
        * Add `:comeonin` for managing our password hashing

## Managing Registration Changesets

* `user.ex`

    ```
    def registration_changeset(model, params) do
      model        |> changeset(params)        |> cast(params, ~w(password), [])        |> validate_length(:password, min: 6, max: 100)
        |> put_pass_hash()    end

    defp put_pass_hash(changeset) do
      case changeset do        %Ecto.Changeset{valid?: true, changes: %{password: pass}} ->
            put_change(changeset, :password_hash, Comeonin.Bcrypt.hashpwsalt(pass))        _ ->
          changeset      end
    end
    ```
    
    * Check the changeset is valid then use `comonin` to hash password
        * just following the instruction in the `comonin` `readme` file.

```
> alias Rumbl.User> changeset = User.registration_changeset(%User{}, %{
username: "max", name: "Max", password: "123"})

%Ecto.Changeset{action: nil, changes: %{name: "Max", password: "123", username: "max"}, constraints: [], errors: [password: {"should be at least %{count} character(s)", [count: ...

> changeset.valid?
false

> changeset.changes
%{name: "Max", password: "123", username: "max"}
```

* `changeset.changes`
    * note `password_hash` is missing
* creating a user with bad password results in an invalid changeset


```
for u <- Rumbl.Repo.all(User) do  Rumbl.Repo.update!(User.registration_changeset(u, %{    password: u.password_hash || "temppass"  }))end

#
# Alternative syntax
#
> for u <- Rumbl.Repo.all(User) do
    User.registration_changeset(u, %{password: "temppass"}) |> Rumbl.Repo.update!
  end
```

## Creating Users


* Use `User.registration_changeset` in `user_controller.ex`

    ```
    def create(conn, %{"user" => user_params}) do      changeset = User.registration_changeset(%User{}, user_params)
      case Repo.insert(changeset) do        {:ok, user} -> conn          |> put_flash(:info, "#{user.name} created!")          |> redirect(to: user_path(conn, :index))
        {:error, changeset} ->          render(conn, "new.html", changeset: changeset)
      end    end
    ```
 * The changeset insulates the controller from the change policies encoded in the model layer whie keeping the model free of side effects
     * Similar to connection pipelines, validations are a pipeline of functions that transform the changeset
     * The changeset data structure explicitly tracks changes and their validity
     * Actual changes happen only when we call the repository in the controller

## The Anatomy of a Plug

* Two kinds of plugs
    * *module plugs*
        * a module that provides *two* functions
        * `plug Plug.Logger`
    * *function plugs*
        * a single function
        * `plug :protect_from_forgery`

### Module Plugs

* Allow to share a plug across more than one module
* Must provide `init` and `call`

    ```
    defmodule NothingPlug do
      def init(opts) do
        opts
      end
    
      def call(conn, _opts) do
        conn
      end
    end
    ```
    
    * Remember a typical plug transforms a connection
    * the main work happens in `call`; happens at *runtime*
    * `init` to do some heavy lifting to transform options
        * happen at *compile time*
        * plug use the result of `init` as second argument to `call`
* Both module and function plugs have the same request interface

### ``Plug.Conn` Fields

* the structure has the various fields that web applications to understand about web requests and responses

* `host`: the requested host, ie. `www.pragprog.com`
* `method`: the request method, ie. `GET`
* `path_info`: the path split into a List of segments, ie `["admin", "users"]`
* `req_headers`: a list of request headers, ie. `[{"content-type", "text/plain"}]`
* `schema`: the request protocol, ie. `:https`
* And other information such as the query string, remote address

#### *fetchable fields*

* A fetchable field is empty until you explicitly request it

* `cookies`: the request cookies and the response cookies
* `params`: the request parameters; some plugs help to parse these parameters from the query string or from the resquest body

#### A series of fiels to process web requests

* `assigns`: user defined map contains anything you want to put in it
* `halted`: sometimes a connection must be halted, ie a failed authorization
* `state`: the state of the connection; if a response has been `:set`, `:sent` or more by introspecting it
* `secret_key_base` for everything related to encryption

#### Fields for Response

* `resp_body`: initially an empty string - the response body will contain the hTTP response string when it's available
* `resp_cookies`: the outbound cookies for the response
* `resp_headers`: HTTP Headers, ie. caching rules
* `status`: HTTP Response status

#### Private field reserved for the adapter and frameworks

* `adapter`: information about the adapter is created here
* `private`: the field has a map for the private use of frameworks

Initially a `conn` comes in almost blank and is filled out progressively by different plugs in the pipeline

* the end point may parse parameters
* the application developer will set fields primaryly in `assigns`


> `Plug.Conn` also defines many functions that directly manipulate those fields
> to abstract away more complex operation suc has managing cookies and sending
> files straightforward

## Writing an Authentication Plug

* Authentication works in two stages
    * first store the user ID in the session every time a user registers or a user logs in
    * second, we'll check if there's a new user in the session and store it in `conn.assigns`

```
defmodule Rumbl.Auth do
  import Plug.Conn

  def init(opts) do
    Keyword.fetch!(opts, :repo)
  end

  def call(conn, repo) do
    user_id = get_session(conn, :user_id)
    user = user_id && repo.get(Rumbl.User, user_id)
    assign(conn, :current_user, user)
  end
end
```

* `init` extract the repository
    * `Keyword.fetch!` raises exception if the given key doesn't exist
        * `Rumbl.Auth` always requires the `:repo`
* `call` receives the repository from `init`
    * check if `:user_id` is stored in the session
    * if so, look up  and assign the result in the connection 

* add the plug in `router.ex` 

    ```
      pipeline :browser do
        plug :accepts, ["html"]
        plug :fetch_session
        plug :fetch_flash
        plug :protect_from_forgery
        plug :put_secure_browser_headers
        plug Rumbl.Auth, repo: Rumbl.Repo
      end
    ```

## Restricting Access

* `Rumbl.Auth` plug process the request information and transforms the `conn` adding `:current_user` to `conn.assigns`
* Use this information to restrict access to pages

```
def index(conn, _params) do
  case authenticate(conn) do
    %Plug.Conn{halted: true} = conn ->
      conn    conn ->      users = Repo.all(User)    render conn, "index.html", users: users  end
end
```

### Extract out as `plug`

* `user_controller.ex`

    ```
        plug :authenticate when action in [:index, :show]

    def index(conn, _params) do      users = Repo.all(Rumbl.User)      render conn, "index.html", users: users    end

    defp authenticate(conn, _opts) do
      if conn.assigns.current_user do        conn      else        conn
        |> put_flash(:error, "You must be logged in to access that page")
        |> redirect(to: page_path(conn, :index))        |> halt()      end
    end
    ```
    
    * What happens to the explicit checking of `halted: true` previously in `index`?
        * Plug pipelines explicitly check for `halted: true` between every plug invocation


### `plug` macro expansion

```
plug :oneplug Twoplug :three, some: :option
```

is transformed to

```
case one(conn, []) do
  %{halted: true} = conn -> conn
  conn ->
    case Two.call(conn, Twoinit([]) do
      %{halted: true} = conn -> conn
      conn ->
        case three(conn, some: :option) do
          %{halted: true} = conn -> conn
          conn -> conn
        end
    end
end
```
    
## Logging In

* `auth.ex`

```
def login(conn, user) do
  conn
  |> assign(:current_user, user)
  |> put_session(:user_id, user.id)
  |> configure_session(renew: true)
end
```

* Recall `conn` has a field called `assigns`

## Implementing Login and Logout

## Wrapping Up

* Add `comeonin` dependency
* Built our own authentication layer
* Built the associated changesets to handle validation of passwords
* Implemented a module plug that loads the user from the session and made it part of our browser pipeline
* Implemented a function plug and used it alongside some specific actions in our controller pipeline
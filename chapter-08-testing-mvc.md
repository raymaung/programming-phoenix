# Chapter 08 - Testing MVC

* Testing principles
    * Fast
    * Isolated
    * DRY
    * Repeatable

* Unit Test
    * Test a function for *one layer* of your application
* Integration Test
    *  Focuses on the way different layers of an application
* Acceptance Test
    * Test how multiple actions works together

## Understanding ExUnit

ExUnit has three main macros

* `setup`
    * sets up code to run before each test
* `test`
    * defines a single isolated test
* `assert`
    * specifies something believe to be true

```
defmodule MyTest do
  use ExUnit.Case, async: true

  setup do
    # run some tedious setup code :ok
  end

  test "pass" do
    assert true
  end

  test "fail" do 
    assert false
  end
end
```

* Run two tests
    * Run `setup`
    * Run `pass` test
    * Run `setup` - again
    * Run `fail` 

## Using Mix to Run Phoenix Tests

* `> mix test` to run tests



```
defmodule Rumbl.PageControllerTest do
  use Rumbl.ConnCase

  test "GET /", %{conn: conn} do
    conn = get conn, "/"
    assert html_response(conn, 200) =~ "Welcome to Phoenix!"
  end
end
```
* Notice `Rumbl.ConnCase`, Phoenix adds `test/support/conn_case.ex` to each new project 
* `conn_case.ex`
    * `Phoenix.ConnTest` to set up that API
    * Import convenient aliases
    * set `@endpoint` required for `Phoenix.ConnTest`
    * `setup tags do ...` `tags` as arguments alongside any test metadata
        * If a given test isn't asynchronous, 
            * it assumes that the test needs the database and restart the database transaction to run on clean slate
* `page_controller_test`
    *  `get conn, "/"` instead of calling the `index` action directly
        *  gives *the right level of isolation*
    *  Phoenix gives us some helpers to test responses and keep the tests clean
        * `assert html_response(conn, 200) =~ "Welcome to Phoenix!"`
            * `html_response(conn, 200)`
                * asserts that the conn's response was `200`
                * asserts that the response `content-type` was `text/html`
                * Returns the reponse body to match the contents
            * Use `json_response` for a JSON response
                * `assert %{user_id: user.id} = json_response(conn, 200)`

## Integration Tests

* One of basic principles for testing is *Isolation*
    * but the most extreme isolation is always the right answer
* Phoenix provides a natural barrier to enforce the balance
    * Test the route through the end point
        * executes plugs and
        * pick up  all of the little transformations that occur along the way
        * Just as a real web request will do
    * Testing through the end point is superfast with virtually no penalty

## Creating Test Data

* `test/support/test_helpers.ex`
* Best approach is to start slowly with functions
    * then add as your needs, ie. unique sequences and faked unique data, grow

## Testing Logged-Out Users

```
> mix test test/controllers/page_controller_test.exs:4
```
    * Run one test at line 4

## Preparing for Logged-In Users

* You might be tempted for place the `user_id` in the session for the `Auth` plug
    * the approach is messy; you don't want to store directly in the session
        * don't want to leak implementation details
* Instead, test the login mechanism in isolation and build a bypass mechanism

* `auth.ex`
    ```
    def call(conn, repo) do
      user_id = get_session(conn, :user_id)
      cond do
        user = conn.assigns[:current_user] ->
          conn
        user = user_id && repo.get(Rumbl.User, user_id) ->
          assign(conn, :current_user, user)
        true ->
          assign(conn, :current_user, nil)
      end
    end
    ```
    * Rewritten `call` to check multiple conditions
        * Adding the code to make it more *testable*
        * If a `user` in `conn.assigns`, honor it no matter

## Testing Logged-In Users

* Add `user` to `conn` to pretend logged-in user
    ```
    setup do      user = insert_user(username: "max")      conn = assign(conn(), :current_user, user)
      {:ok, conn: conn, user: user}    end
    ```

## Controlling Duplication with Tagging

```
setup %{conn: conn} = config do
  if username = config[:login_as] do
    user = insert_user(username: "max")
    conn = assign(conn(), :current_user, user)
    {:ok, conn: conn, user: user}
  else
    :ok
  end
end

@tag login_as: "max"
test "lists all user's videos on index", %{conn: conn, user: user} do
    ...
end
```

* `@tag` to control `setup`
* `> mix test test/controllers --only login_as`
    * Run `login_as` tagged test only

> Negative tests is a delicate balance, don't want to cover all possible
> failure conditions. Handle concerns we shoose to expose to the user

## Unit-Testing Plugs

* `auth.exs`
    ```
    setup %{conn: conn} do
      conn =
        conn
        |> bypass_through(Rumbl.Router, :browser)
        |> get("/")
      {:ok, %{conn: conn}}
    end
    ```
    *  Phoenix includes `bypass_through` test helper to prepare a connection
    *  `bypass_through` provided by `ConnCase`,
        *  allows to send a connection through
            * the end point
            * router, and
            * desiered pipelines
            * but bypass the route dispatch

> Seeding user with registration changesets, hashs password make
> running test expensive
> 
> `config :comeonin, :bcrypt_log_rounds, 4`
> `config :comeonin, :pbkdf2_rounds, 1`
> Ease up the number of hashing rounds to speed up the test suite

## Testing Views and Templates

* Phoenix templates are simply functions in a parent's view module
    * can test these functions just like any other
* Sometimes views are simple enough that your integration tests will be enough
* Many other times, you won't test the templates directly but the functions

## Splitting Side Effects in Model Tests

* Split model tests by their reliance on side effects
* Phoenix, like `Rumbl.ConnCase` generates a module in `test/support/model_case.ex` 
    * `using` block serves as place for common imports and aliases
    * `set tags do ...` for handling transactional tests
    * `errors_on` function for quickly accessing a list of error messages for attributes on a given model

## Testing Side Effect-Free Model Code

* Try to make as much of the application side effect free as possible
* Tests will be easier to understand and will run faster

## Testing Code with Side Effects

* Handle the cases there are side effects; ie. *repository tests*
* Most repository-related functionality will be tested with integration tests
* We want to be sure we catch some error conditions *as close to the breaking point as possible*
    * Example: Uniqueness constraint check

    
## Wrapping Up

* Examined how tests work in Phoenix
* Set up some basic testing functions to insert users and videos and shared those across all of our potential test cases
* Wrote soem basic integration tests
* Used Phoenix test helpers to make multiple assertions
* Tested authentication plug in isolation
* Tests the views
* Tested models with and without side effects
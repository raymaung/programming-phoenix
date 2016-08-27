# Chapter 07 - Ecto Queries and Constraints

## Adding Categories

```
> mix phoenix.gen.model Category categories name:string
```

### Generating Category Migrations

* Update to require `name`
    * `add :name, :string, null: false`

* Add category to video

```
> mix ecto.gen.migration add_category_id_to_video
```

```
def change do  alter table(:videos) do    add :category_id, references(:categories)
  endend
```

### Setting Up Category Seed Data

* Expect the categories to be fixed; add to `seeds.exs`

    ```
    alias Rumbl.Repo
    alias Rumbl.Category

    for category <- ~w(Action Drama Romance Comedy Sci-fi) do
      Repo.insert! %Category{name: category}
    end
    ```

* `mix run priv/repo/seeds.exs`

### Associating Videos and Categories

```
> import Ecto.Query
> alias Rumbl.Repo
> alias Rumbl.Category

> Repo.all from c in Category, select: c.name
[debug] QUERY OK db=1.4ms decode=2.3ms
SELECT c0."name" FROM "categories" AS c0 []
["Action", "Drama", "Romance", "Comedy", "Sci-fi"]


> Repo.all from c in Category, order_by: c.name, select: {c.name, c.id}
[debug] QUERY OK db=2.1ms
SELECT c0."name", c0."id" FROM "categories" AS c0 ORDER BY c0."name" []
[{"Action", 1}, {"Comedy", 4}, {"Drama", 2}, {"Romance", 3}, {"Sci-fi", 5}]

> query = Category
> query = from c in query, order_by: c.name
#Ecto.Query<>

> query = from c in query, select: {c.name, c.id}
> #Ecto.Query<>

> Repo.all query
[{"Action", 1}, {"Comedy", 4}, {"Drama", 2}, {"Romance", 3}, {"Sci-fi", 5}]
```

* `Repo.all`: return all rows
* `from` is a macro that builds a query
* `c in Category` means pulling row (labeled `c`) from `Category`
* `select: c.name` returns only the `name` field
* Instead of building the whole query at once, you can write it in a small steps

> Both `Repo.all Category` and `Repo.all query` works because
> both `Category` and `query` implement the `Ecto.Queryable` protocol

## Diving Deeper into Ecto Queries

```
> import Ecto.Query
> alias Rumbl.Repo
> alias Rumbl.User

> username = "josevalim"
> Repo.one(from u in User, where: u.username == ^username)
%Rumbl.User{username: "josevalim"...}
```

* `Repo.one` means return one row
    * Not return the first result
* `from u in User` means reading from `User` scheam
* `where: u.username == ^username` means return the row where `u.username == ^username`, `^` (the pin operator) means keep `^username` the same
* When the `select` part is omitted, the whole struct is returned as if we'd written `select: u`


* The Query Language is different
    * It is *NOT* just a composition of strings
    * by relying Elixir macros, Ecto know where user-defined variables are loacated
        * Easier to protect the user from security flaws like SQL-injections attacks

    * Ecto queries also do a good part of the query normalization at compile time


```
> username = 123
123

> Repo.one(from u in User, where: u.username == ^username)
** Ecto.CastError ...
```
* `^` operator interpolates values into the queries where Ecto can scrub them and safely put them to user, without the risk of SQL injection
    * Armed with our schema definitionsEcto is able to cast the value the values property

* Define the repository and schemas and let Ecto changesets and queries tie them up together
    * give developers the proper level of isolation
        * developers work mostly with data, leave all complex operatiosn to the repository

> Keep functions with side effects, in the controller while
> the model and view layers remain side effect free.

Since Ecto splits the responsibilities between the repository and its data API
it fits the world perfectly

* See Pg 116 - 
    * When a request comes in the Controller invoked
        * Controller read data from the socket (a side effect)
        * parse it into data structures like `params`
    * Elixir structs and Ecto changesets and queries are just data
        * can build or transform by passing them from function to function
        * slightly modifying the data on each step, shap the business model requirements
        * Invoke the entities that can change the world, like
            * the repository (Repo) or
            * the system responsible for delivering emails (Mail)
        * Invoke the view
            * converts the model data (ie. structs or changesets) into view data such as JSON maps or HTML strings
                * then written to the socket via the controller - another side effect

Because the controller already encapsulates side effects by reading and writting to the socket, it is the perfect place to put interfactions with repository while the model and view layers are kept free of side effects

### The Query API

* Ecto supports a side range of operators
    * Comparison operators: `==`, `!=`, `<=`, `>=`, `<`, `>`
    * Boolean operators, `and`, `or`, `not` 
    * Inclusion operator `in`
    * Search functions `like` and `ilike`
    * Null check functsion `is_nil`
    * Aggregates `count`, `avg`, `sum`, `min`, `max`
    * Date/time intervals `datetime_add`, `date_add`
    * General `fragment` `field`, `type`
* Doc in `Ecto.Query.API`

### Writing Queries with Keywords Syntax

```
> Repo.one from u in User,
    select: count(u.id),
    where: ilike(u.username, ^"j%") or
           ilike(u.username, ^"c%")
2
```

* `u` is bound as part of Ecto's `from` macro
* Bindings are useful when our queries need to join across multiple schemas
    * Each join in a query gets a specific binding

```
> users_count = from u in User, select: count(u.id)
#Ecto.Query<from u in Rumbl.User, select: count(u.id)>

> j_users = from u in users_count, where: ilike(u.username, ^"%j%")
> j_users = from q in users_count, where: ilike(q.username, ^"%j%")
```
* use `from` to build a query, selecting `count(u.id)`
* `j_users = from u in users_count, where: ilike(u.username, ^"%j%")`
    * Free to name the query variables however you like 
    * `j_users = from u in users_count, where: ilike(u.username, ^"%j%")`

## Using Queries with the Pipe Synntax

```
> User |>
   select([u], count(u.id)) |>
   where([u], ilike(u.username, ^"j%") or ilike(u.username, ^"c%")) |>
   Repo.one()

[debug] QUERY OK db=2.0ms
SELECT count(u0."id") FROM "users" AS u0 WHERE ((u0."username" ILIKE $1) OR (u0."username" ILIKE $2)) ["j%", "c%"]
3
```

* Because each query is independent of others, we need to specify the binding manually for each one as part of a list
    * this binding is conceptually the same as the one we used in `from u in User`
* The query syntax depends on taste and the problems

### Fragments

* *query fragment* sends part of a query directly to the database but allows you to construct the query string in a safe way

```
from (u in User,
        where: fragment("lower(username) = ?",
                         ^String.downcase(uname)))
```
* fragment allows us to construct a fragment of SQL for the query but safely interpolate the `String.downcase(uname)`

```
> Ecto.Adapters.SQL.query(Rumbl.Repo, "SELECT power($1, $2)", [2, 10])
[debug] QUERY OK db=2.4ms
SELECT power($1, $2) [2, 10]
{:ok,
 %Postgrex.Result{columns: ["power"], command: :select, connection_id: 14597,
  num_rows: 1, rows: [[1024.0]]}}
```

### Querying Relations

* Ecto queries also offer support for associations
* Ecto associations are explicit - use `Repo.preload` to fetch associated data

```
> user = Repo.one from(u in User, limit: 1)
%Rumbl.User{...}

> user.videos
#Ecto.Association.NotLoaded<association :videos is not loaded>

> user = Repo.preload(user, :videos)
%Rumbl.User{...}

> user.videos
[]
```

* We don't always need to preload associations as a separate step
* Ecto allows us to preload associations directly as part of a query like

    ```
    > user = Repo.one from(u in User, limit: 1, preload: [:videos])
    %Rumbl.User{...}
    
    > user.videos
    []
    ```
* Join an associations inside queries

    ```
    > Repo.all from u in User,
            join: v in assoc(u, :videos),
            join: c in assoc(v, :category),
          where: c.name == "Comedy",
        select: {u, v}
    [{%Rumbl.User{...}, %Rumbl.Video{...}}]
    ```
    
    * Ecto now returns users and videos side by side as long as the video belongs to the `Comedy`

### Constraints

* Constraints allow to maintain database integrity

```
1. The user sends a category ID through the from
2. We perform a query to check if the category ID exists in the database
3. If the category ID does exist in the database, we add the video with the category ID to the database
```
* If some one delete the category between step 2 and 3, allowing to ultimate insert video without an existing category in the database
    * could create *inconsistent* data over time

* *constraints*
    * An explicit database constraint - uniqueness constraint on an index or an integrity constraint between primary and foreign keys
* *constraints error*
    * `Ecto.ConstraintError` 
* *changeset constraint*
    * A constraint annotation added to the changeset that allows Ecto to convert constraint errors into changeset error messages
* *changeset error messages* 
    * Beautiful error messages for the human

#### Three Approaches

* Application manages constraints
* Database manages all code that touches data - through the use of stored procedures
* Hybird Approach - the application layer uses database services like referential integrity and transactions
    * Ecto uses this approach and also most database layers

### Validating Unique Data

* `create unique_index(:users, [:username])` in the user table migration script

```
def changeset(model, params \\ :empty) do
  model  |> cast(params, ~w(name username), [])  |> validate_length(:username, min: 1, max: 20)
  |> unique_constraint(:username)end
```

* Pipe the changeset into `unique_constraint` only one of the different constraint mappins that changesets offer

### Validating Foreign Keys

```
def changeset(model, params \\ :empty) do
  model  |> cast(params, @required_fields, @optional_fields)  |> assoc_constraint(:category)
end
```
* `assoc_constraint` converts foreign-key constraints erros into human readable error messages

```
iex> alias Rumbl.Category
iex> alias Rumbl.Video
iex> alias Rumbl.Repo
iex> import Ecto.Queryiex> category = Repo.get_by Category, name: "Drama"
%Rumbl.Category{...}iex> video = Repo.one(from v in Video, limit: 1)
...%Rumbl.Video{...}

iex> changeset = Video.changeset(video, %{category_id: category.id})
iex> Repo.update(changeset)
...{:ok, %Rumbl.Video{...}}

```
* Works


```
iex> changeset = Video.changeset(video, %{category_id: 12345})
iex> Repo.update(changeset)
...{:error, %Ecto.Changeset{}}

iex> {:error, changeset} = v(-1)
iex> changeset.errors[category: "does not exist"]
```

* Updating with bad category fails
* `v(-1)` refers to the IEX line number 

### On Delete

```
> alias Rumbl.Repo
> category = Repo.get_by Rumbl.Category, name: "Drama"

> Repo.delete category** (Ecto.ConstraintError) constraint error when attempting to delete struct
```
* Can't delete the category because it would leave orphaned records
* Like insert and update, `Repo.delete` also accepts a changeset
* You can use `foreign_key_constraint` to ensure that no associated videos exist
    * similar to `assoc_constraint` except it doesn't inflect the foreign key from the relationship
    * useful when you want to show the user why you can't delete the category

    ```
    > import Ecto.Changeset
    > changeset = Ecto.Changeset.change(category)
    > changeset = foreign_key_constraint(changeset, :videos,        name: :videos_category_id_fkey, message: "still exist")
    
    > Repo.delete changeset
    [debug] QUERY ERROR db=3.0ms
        DELETE FROM "categories" WHERE "id" = $1 [2]
    {:error,
     #Ecto.Changeset<action: :delete, changes: %{},
      errors: [videos: {"still exist", []}], data: #Rumbl.Category<>,
      valid?: false>}
    ```
    
* A bit more explicit in `foreign_key_constraint` because the foreign key has been set in the videos table
    * If needed add `no_assoc_constraint` to do the dirty work of lifting the foreign-key name and setting a good error message


Second you could configure the database references to either cascade the deletions or simply make the `videos.category_id` column `NULL` on delete

* From the migration script `add_category_id_to_video`,
    * `add :category_id, references(:categories)`
        * `references` accepts
            * `:nothing` the default
            * `:delete_all`
                * when the category is deleted, all videos in that category are deleted
            * `:nillify_all` 
                * when a category is deleted the `category_id` of all associated videos is set to `NULL`
        * No best option here

    > The work best suited to the databae must be done in the database

### Let It Crash

* when the user can do nothing to fix the error, so crashing is the best option
    * Unexpected happens but that's ok - Elixir is designed to handle failures

## Wrapping Up

* Ecto's query API is independent of the repository API to do some basic queries
* Two forms of queires
    * keyword list based syntax
    * pipe based syntax
* Fragments to pass sQL commands through the query API
* Different ways Ecto queries work with relationships beyond data preloading
* Constraint-style validation
* Choose between letting constraint errors go and when to report them to the user
    
# Chapter 06 - Generators and Relationships

## Using Generators

### Generating Resources

* Phoenix includes two Mix tasks to bootstrap applications
    * `phoenix.gen.html` creates a simple HTTP scaffold with HTML pages
    * `phoenix.gen.json` does the same for a REST-based API
* You get migrations, controllers and templates for basic CRUD operations of a resource and tests
    * You won't write all your Phoenix this way but the generators are a great way to get up and running quickly

```
> mix phoenix.gen.html Video videos user_id:references:users url:string title:string description:text
```
    * the name of the module that defines the model
    * the plural form of the model name
        * instead of the framework inflect plural and singularforms as requests
    * Each field with type information

> Phoenix free you from memorizing unnecessary singular and plural
> conventions by consistenly using singular forms in models, controllers
> and views

* Move `authenticate` from `UserController` to `Auth`
    * Need to `import Phoenix.Controller` to get access to `put_flash` and `redirect`   
    * `alias Rumbl.Router.Helpers` to use `Helpers.page_path`
        * Not `import Rumbl.Router.Helpers`
            * to avoid circular dependency between the router and the auth module as we also want to use the auth module in the router module

* `web/router.ex`

    ```
    scope "/manage", Rumbl do      pipe_through [:browser, :authenticate_user]      resources "/videos", VideoController
    end
    ```
    
    * Pipe through `:browser` and `:authenticate_user`
        * Because pipelines are also plugs, you can pipe through `:authenticate_user`

## Examining the Generated Controller and View

* the generated controller contains all REST actions
* `VideoController` like any other controller, also has a pipeline
    * Phoenix generator plugs a function called `scub_params` for the `create` and `update`
    * `plug :scrub_params, "video" when action in [:create, :update]`
* HTML forms don't have the concept of `nil`
    * every time a blank input is sent, it arrives as an empty string
        * If we didn't scrub those empty strings out, they would leak throught the application forcing to differentiate between `nil` and blank strings everywhere


### Generated Migrations

* `repo/migration/200xxx_create_video.exs`

```
def change do
  create table(:videos) do
    add :url, :string
    add :title, :string
    add :description, :text
    add :user_id, references(:users, on_delete: :nothing)

    timestamps()
  
  end
   
  create index(:videos, [:user_id])

end
```    

* Phoenix generated all the fields passed from the command line
* `change` function handles two database changes
    * migrating up
        * `> mix ecto.migrate` to migrate
    * migrating down
        * `> mix ecto.rollback` to roll back


## Building Relationships

* `models/vide.ex`

    ```
    schema "videos" do
      field :url, :string
      field :title, :string
      field :description, :string
      belongs_to :user, Rumbl.User

      timestamps()
    end
    ```

* `belongs_to` defines an association
* migration file defines `:user_id` foreign key

* `models/user.ex`

    ```
    schema "users" do      field :name, :string      field :username, :string      field :password, :string, virtual: true field :password_hash, :string      has_many :videos, Rumbl.Video      timestamps    end
    ```
* `has_many` defines *one-to-many* association

```
> alias Rumbl.Repo
> alias Rumbl.User
> import Ecto.Query

> user = Repo.get_by!(User, username: "josevalim")
%Rumbl.User{...}

> user = Repo.get_by!(User, username: "josevalim")
#Ecto.Association.NotLoaded<association :videos is not loaded>
```
* Ecto associations are **explicit**
    * when you want Ecto to fetch some records, you need to ask
    * Seem tedious at first, but useful
        * one of the most time-consuming things is fetching rows you don't need, or fetch in inefficient ways
    * That's why returning `Ecto.Association.NotLoaded` 

```
> user = Repo.preload(user, :video)
%Rumbl.User{...}

> user.videos
[]
```
* `Repo.preload` accepts one or a collection of association ames and fetch all associated data



```
> user = Repo.get_by!(User, username: "josevalim")
%Rumbl.User{...}

> video = Ecto.build_assoc(user, :videos, attrs)
%Rumbl.Video{...}

> video = Repo.insert!(video)
%Rumbl.Video{...}
```
* `Ecto.build_assoc` allows to build a struct with the property relationship fields
* Equivalent

    ```
    > %Rumbl.Video{user_id: user.id, title: "hi", description: "says hi", url: "example.com"}
    ``` 
    

```
> user = Repo.get_by!(User, username: "josevalim")
%Rumbl.User{...}

> user = Repo.preload(user, :videos)
%Rumbl.User{...}

> user.videos
[%Rumbl.Video{...}]
```

* Preload is great for bundling data, but other times we want to fetch the videos associated with a user without storing them in the user struct

    ```
    > query = Ecto.assoc(user, :videos)
    #Ecto.Query<...>
    
    > Repo.all query
    [%Rumbl.Video{...}]
    ```

    * `assoc` is another convenient function from `Ecto`  that returns `Ecto.Query`
    * Convert the `query` to data with `Repo.all`

## Managing Related Data

* Need to change so the video is built with the `user_id`
    * `user_id` is available in `conn.assigns.current_user`
* `build_assoc` 
* From `web.ex` we know all controllers import `Ecto` 
* since all actions depend on the `current_user`, Phoenix allows us to make this dependency clearer by removing the boiler plate with a custom `action` in the controller
    ```
    def action(conn, _) do
      apply(__MODULE__, action_name(conn),        [conn, conn.params, conn.assigns.current_user])    end
    ```

    * Every controller has its own default `action` function 
    * It is a plug that dispatches to the proper action at the end of the controller pipeline
    * We are replacing it beccause we want to change the API for our controller actions
    * We call `apply` to call our action the way we want
        * Instead of using the module name, using `__MODULE__`

* Use `user` passed to the action, associate the video on create

* `video_controller.ex`
```
defp user_videos(user) do
  assoc(user, :videos)end
```
* Use `user_videos` for other actions ie. `show`  to gurantees that users can only access the information from videos they own

## Wrapping Up

* Converted a private plug into a public function to share with controllers and routers
* Leanred how to migrate and roll back
* Defiend relationsihps between `User` and `Video`
* Learned Ecto explicit semantics to determine a relationship is loaded or now
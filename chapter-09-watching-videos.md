# Chapter 09 - Watching Videos

## Watching Videos

## Adding JavaScript

* *Brunch* is a build tool written in Node.js
* Use Brunch to build transform, minify JavaScript code
    * not just JavaScript
    * also CSS and 
    * all of the application assets, ie. images

* Branch Structure
    ```
    ...    ├── assets
    ├── css
    ├── js
    ├── vendor
    ...
    ```
    * Put everything in `assets` that *doesnt* need to be transformed by Branch
        * Build tool will simply copy those `assets` as they are to `priv/static` where they'll be served by `Phoenix.Static`

    * Keep CSS and JavaScript files in their respective directories
    * `vendor` folder is used to keep any third party tools
    * see `app.js`

### Tooling Set Up
* `npm install -g brunch`
* Add `babel-preset` to `package.json`
    ```
    "devDependencies": {
      "babel-preset-es2015": "6.14.0"
    }
    ```
* Watch
    ```
    > brunch build --production
    > brunch watch
    ```
* `config/dev.exs`
    ```
    watchers: [node: ["node_modules/brunch/bin/brunch", "watch", "--stdin"]]
    ```

    * Automatically run `brunch watch --stdin`
        * `--stdin` makes the `brunch` abort when Phoenix shuts down

## Creating Slugs

* `> mix ecto.gen.migration add_slug_to_video` to add a slug col to video
* Update the changeset in `video.ex`
* Note, you don't have to touch the controller
    * Ecto separates changesets from the definition of a given record
    * Changesets filter and cast the incoming data
    * changesets can validate data
* Ecto cleanly encapsulates the concepts of change

* `web/templates/video/index.html`
    * Use `watch_path(@conn, :show, "#{video.id}-#{video.slug}")` as watch path
    * But it is brittle - not DRY

### Customizing How Phoenix Generates URL

* Phoenix knows to use the `id` field in `Video` struct
* Phoenix defines the `Phoenix.Param` protocol
    * By default, the protocol extracts the `id` of the struct
    * As it is an Elixir protocol, you can customize it
    * `video.ex`

        ```
        defimpl Phoenix.Param, for: Rumbl.Video do
          def to_param(%{slug: slug, id: id}) do            "#{id}-#{slug}"
          end        end
        ``` 

    * Testing in IEX
        ```
        > video = %Rumbl.Video{id: 1, slug: "hello"}
        %Rumbl.Video{id: 1, slug: "hello", ...}        > Rumbl.Router.Helpers.watch_path(%URI{}, :show, video)
        "/watch/1-hello"
        ```
### Extending Schemas with Ecto Types

* The basic type information in our schemas isn't enough.
    * in those cases, we'd like to improve the schemas with types that have a knowledge of Ecto
    * ie. we might want to associate some behavior to our `id` fields
    * A *custom type* allow to do that `lib/rumbl/permalink.ex`

* `Rumbl.Permalink`
    * a custom type defined according to the `Ecto.Type`, expects to define four functions
        * `type` returns the underlying Ecto tpe - ie. we're building on top of `:id`
        * `cast` called when external data is passed into Ecto.
            * invoked when values in queries are interpolated or also by the `cast` function in changesets
        * `dump` invoked when data is sent *to* the database
        * `load` invoked when data is loaded *from* the database
    * By design the `cast` function often processes end-user input
        * we should be both lenient and careful when parse it

## Wrapping Up

* Learn to use Brunch to support development time reloading and minimization for production code
* Used generators to create an Ecto migration
* Used changesets to create slugs
* Used protocols to seamlessly build URLs from those new slugs
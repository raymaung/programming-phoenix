# Chapter 12 - Observer and Umbrellas

* `Rumbl` Information Systems is a feature that's reasonably complete on its own.
* We'll refactor the application into umbrella projects
* Umbrella projects allow you to develop and test multiple child applications in isolation

## Introspecting with Observer

* Observer is a greate tool for understanding all running processes for the application

    ```
    $ iex -S mix
    
    > :observer.start
    ```

* Remember, in Elixir, all state exists in your processes
* With Observer you can see the state of our entire system and who's responsible for each piece

## Using Umbrellas

* Each umbrella project has a parent directory that defines
    * the shared configuration of the project
    * the dependencies for that project
    * the `apps` directory with child applications

## Making `rumbl` an Umbrella Child

* Physically moved `rumbl` to the `rumbrella` project under `apps/`
* Update `mix.exs` to tell Elixir where to find the umbrella files
* Removed `info_sys` from our supervisor child list
    * it is now responsibilities of umbrella project now
* Changed `Rumbl.InfoSysm` references to `InfoSys`
* Changed `:wolfram` project key to pull it from the umbrella project to remove our product key
* Tweak the paths in our front-end code

```
$ cd rumbrella
$ mix deps.get
$ mix test
```

## Wrapping Up

* Use Observer to view our application
* Found a convenient place to split our application
* Moved our information system into its own child umbrella project
* Moved `rumbl` into its own child umbrella project
* Learned to identify configuration changes, including
    * dependencies
    * supervision trees and
    * application configuration
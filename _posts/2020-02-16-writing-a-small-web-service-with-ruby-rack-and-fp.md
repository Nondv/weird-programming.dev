---
title: Writing a small web service with Ruby, Rack, and functional programming
categories: [fp]
tags: [ruby, rack, fp, functional programming]
---

*Originally posted on [medium.com](https://levelup.gitconnected.com/writing-a-small-web-service-with-ruby-rack-and-functional-programming-a16f802a19c0)*

I love Ruby. I also love object-oriented programming. However, nowadays
functional programming is getting more and more attention. And that’s not
surprising because the functional paradigm has a lot of advantages.

Ruby, being a multi-paradigm language, allows us to write programs in a
functional style. Let’s see if we can write a web application this way. Maybe we
even end up inventing a web framework ;)

<!--more-->

# Ground rules

Let’s establish some ground rules.

1. Lambdas. Lambdas everywhere
2. Arrays. We can use arrays and some methods from `Enumerable` like `#map`,
   `#reduce`, `#find`, `#select`, `#reject`
3. Hashes. We can access values via [key] and use merge for modifying them
   (no mutations!)
4. Keeping external dependencies (like rack utility functions) to a minimum.

# Rack

> Rack provides a minimal, modular, and adaptable interface for developing web
> applications in Ruby.

Rack is used by Rails and Sinatra. You can learn more about it here:
https://github.com/rack/rack

Rack expects an application to be an object with a `#call` method accepting `env`
(hash containing all the information about a request) and returning a 3-element
tuple:

`[status_code, headers_hash, body_array]`

(body array is usually a list of strings)

This is great because it uses basic data structures and the `#call` method
indicates that we can use a lambda/proc as an application.

# Setup

Let’s set up an app first.

## Gemfile

Generate a Gemfile with `bundle init` and add Rack to it.

```ruby
source "https://rubygems.org"
git_source(:github) {|repo_name| "https://github.com/#{repo_name}" }

gem "rack"
```

## config.ru

`config.ru` is a script being run by `rackup` program shipping with Rack and
starting a webserver.

```ruby
require 'rack/reloader'
require_relative 'app'

use Rack::Reloader
run ->(env) { APP.call(env) }
```

Rack reloader will reload our application without restarting the server.

We will also assume that our app source code will define the `APP` constant with
our app lambda. We also need to wrap it into another lambda or Rack won’t pick
up changes to the constant.

## app.rb

```ruby
# frozen_string_literal: true

APP = ->(env) { [200, {}, [env.inspect]] }
```

Now we can start the webserver with `bundle exec rackup`.
It should be available on http://localhost:9292

# Routing

Let’s add a route for `/hello` showing “Hello world” message. Also, a 404 page.

## Handlers

Let’s move our previous lambda from APP to a handler variable.

```ruby
hello_handler = ->(env) { [200, {}, ["Hello world"]] }
env_inspect_handler = ->(env) { [200, {}, [env.inspect]] }
not_found_handler = ->(env) { [404, {}, ["404 Not found"]] }
```

## Routes

Let’s define routes as a list of pairs condition + handler:

```ruby
# Utility constant function
constant = ->(x) { ->(_) { x } }

exact_path_matcher = ->(path) { ->(env) { env['PATH_INFO'] == path } }
routes = [
  [exact_path_matcher['/'], env_inspect_handler],
  [exact_path_matcher['/hello'], hello_handler],
  # else
  [constant[true], not_found_handler]
]
```

We could also make a data type out of routes. For that, instead of explicitly
writing them as pairs we should create a function `route(matcher, handler)` and
getter functions `route_matcher(route)` and `route_handler(route)` . This way
the code becomes more flexible since it won’t know a lot about the data
structure implementation. However, let’s keep it simple.

## Router

A router is a dispatch function that decides which handler to use for a request.

```ruby
comp = ->(f1, f2) { ->(x) { f1[f2[x]] } }
# Utility function to get the handler out of a route
second = ->((_a, b)) { b }

route_matcher = ->(env) { ->((cond, _handler)) { cond[env] } }
find_route = ->(env) { routes.find(&route_matcher[env]) }
find_handler = comp[second, find_route]
router = ->(env) { find_handler[env][env] }

APP = router
```

# Middleware

Let’s make users provide their name to greet them properly.

For that, we need a `params` hash.

## Params middleware

A middleware is just a wrapper over a handler that modifies the `env` or the
result returned from it.

Let’s create a middleware that adds `params` hash to `env` before handing it over to
a handler.

```ruby
query_to_params = ->(q) { Rack::Utils.parse_nested_query(q) }
query_from_env = ->(env) { env['QUERY_STRING'] }
env_to_params = comp[query_to_params, query_from_env]
env_with_params = ->(env) { env.merge(params: env_to_params[env]) }
params_middleware = ->(handler) { comp[handler, env_with_params] }

APP = params_middleware[router]
```

## The handler

Let’s use the new parameter in a handler.

```ruby
hello_handler = ->(env) {
  [200, {}, ["Hello #{env[:params]['name']}"]]
}
```

Now we should be able to see a greeting here:
http://localhost:9292/hello?name=John+Doe

## Content-Type header

Let’s also add text/html content-type header while we are at it.

```ruby
content_type_middleware = ->(type) {
  ->(handler) {
    ->(env) {
      status, headers, body = handler[env]
      [status, headers.merge('Content-Type' => type), body]
    }
  }
}

html_content_type_middleware = content_type_middleware['text/html']
APP = html_content_type_middleware[params_middleware[router]]
```

## Listing middleware

Right now we are adding a middleware by directly calling it on a handler.
It would look nicer if we could just list them and apply later.

```ruby
identity = ->(x) { x }

middleware_list = [
  params_middleware,
  html_content_type_middleware
]
app_middleware = middleware_list.reduce(identity, &comp)

APP = app_middleware[router]
```

The identity function is great. Composing it with another function has zero
effect so it’s great as an init value for reducing.

# Conclusion?

We have implemented a small web application. It doesn’t do much though. However,
it’s interesting how far we could go by just using lambdas, arrays, and hashes.

Database interactions would introduce side-effects to our code. As an idea, they
could be put into methods so it’s easier to distinguish them from pure lambdas.

We could also make a framework from it by moving the essential stuff to hashes
and assigning them to constants. For example,

```ruby
routes_to_router = ->(routes) {
  route_matcher = ->(env) { ->((cond, _handler)) { cond[env] } }
  find_route = ->(env) { routes.find(&route_matcher[env]) }
  find_handler = comp[second, find_route]
  ->(env) { find_handler[env][env] }
}

ROUTING = {
  routes_to_router: routes_to_router
}
```

You can find the complete source code
[here](https://github.com/Nondv/ruby-experiments/tree/master/functional_rack).

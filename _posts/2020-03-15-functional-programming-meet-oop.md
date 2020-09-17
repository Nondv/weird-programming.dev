---
title: Functional programming, meet OOP
author_profile_url: https://nondv.wtf
categories: [oop]
img: /img/posts/bugs-handshake.png
tags: [functional programming, object-oriented programming, fp, oop, clojure]
description: Implementing OOP in a functional programming language
---

*Originally posted on [medium.com](https://medium.com/swlh/functional-programming-meet-oop-3dc12a14e38e)*

I enjoy experimenting with programming paradigms and trying out some interesting
(to me) ideas (some things become posts, like
[this]({%  post_url 2020-01-17-implementing-numbers-in-pure-ruby %}) and
[that]({%  post_url 2020-02-16-writing-a-small-web-service-with-ruby-rack-and-fp %})).
Recently I decided to see if I can write object-oriented code in a functional language.

<!--more-->

# Idea

I was trying to get some inspiration from [Alan Kay](http://www.purl.org/stefan_ram/pub/doc_kay_oop_en),
the creator of object-oriented programming.

> OOP to me means only messaging, local retention and protection and hiding of
> state-process, and extreme late-binding of all things.

I decided that I will be happy if I can implement message sending and inner
state.

So here comes the main problem of the whole concept — the state.

## State

You are not supposed to have a state in functional programming. So how do you
change values in functional programming? Usually, by using recursion
(pseudocode):

```pascal
function list_sum(list, result)
  if empty?
    result
  else
    list_sum(tail(list), result + first(list))
list_sum([1, 2, 3, 4], 0)
```

In imperative programming, we usually create a variable and change its value all
the time. Here we, essentially, are doing the same by calling a function again
with different parameters.

But an object should have a state and receive messages. Let’s try this:

```pascal
function some_object(state)
  msg = receive_message()
  next_state = process_message(msg)
  some_object(next_state)
```

Seems reasonable to me. But this is blocking everything, how do I create other
objects? How do I send messages between them? Well, let me quote Alan Kay again:

> I thought of objects being like biological cells and/or individual computers
> on a network, only able to communicate with messages

This gave me an idea of using parallelism. I called `some_object(state)` function
“object loop” and decided to run it in a separate thread. The only mystery left
so far is messaging.

## Messaging

In terms of messaging, I decided that we can just use
[channels](https://en.wikipedia.org/wiki/Channel_(programming))
(they seem to be incredibly popular in Go programming language). Then
`receive_message()` would be just waiting for a message appearing in a channel
(message queue). Sounds easy enough.

# Language

Initially, I wanted to use Haskell but I don’t know the language so I’d have a
really hard time dealing with laziness, static typing and tons of googling when
all I wanted really was just to make a prototype of my idea. So I decided to use
Clojure since it’s dynamic and is great for interactive programming (which makes
life a lot easier for prototyping and experimenting).

Now, being mixed-paradigm language, it’s possible to have an actual state in
Clojure:

```clojure
(def user (atom {:id 1, :name "John"}))
@user ; ==> {:id 1, :name "John" }
(reset! user {:id 1, :name "John Doe"})
@user ; ==> {:id 1, :name "John Doe"}
```

We will be avoiding using stuff like this, of course.

# Object

So, the core concept of object-oriented programming is an object. Things like
classes are not required (for example, JavaScript, being OOP language, doesn’t
have classes; It emulates them, being prototype-oriented). Let’s start by
implementing objects.

So, what do we need for our object? So far I’ve mentioned “object loop” and
channels. Also, we need `process_message(message)` function.

Clojure has its own implementation of channels in `clojure.core.async` library
so we will be using it. But first, we need to think of data-structure for
representing our object. It’s simple, really:

```clojure
(ns functional-oop.object
  (:require [clojure.core.async :as async]))

(defn- datastructure [message-handler channel]
  {:message-handler message-handler
   :channel channel})
```

Now we just need to add an object loop:

```clojure
(defn- object-loop [obj state]
  (let [message (async/<!! (:channel obj))
        next-state ((:message-handler obj) obj state message)]
    (if (nil? next-state)
      nil
      (recur obj next-state))))
```

`async/<!!` is just a function that waits for the message in a channel. A
message handler is supposed to return next state or nil to stop the loop. Also,
the message handler is supposed to accept the object itself (self), state and,
of course, the message as arguments.

Okay, everything is ready, all we need is to glue it together — initialise an
object:

```clojure
(defn init [state message-handler]
  (let [channel (async/chan 10)
        obj (datastructure message-handler channel)]
    (async/thread (object-loop obj state))
    obj))

(defn send-msg [obj msg]
  (async/>!! (:channel obj) msg))
```

Here we literally just start the loop and return a data structure for other code
to communicate with that. And other code can communicate with the object by
sending it a message via `send-msg`. `async/>!!`, as you might guess, writes
something to a channel.

## Using objects

Okay, but does it work? Let’s try it out. I decided to test it on string
builder.

String builder is just an object that combines a bunch of strings together:

```
builder = new StringBuilder
builder.add "Hello"
builder.add " world"
builder.build # ===> "Hello world"
```

So let’s try it implementing it:

```clojure
(defn message-handler [self state msg]
  (case (:method msg)
    :add (update state :strings conj (:str msg))
    :add-twice (let [add-msg {:method :add, :str (:str msg)}]
                 (object/send-msg self add-msg)
                 (object/send-msg self add-msg)
                 state)
    :reset (assoc state :strings [])
    :build (do
             ((:callback msg) (apply str (:strings state)))
             state)
    :free nil
    ;; ignore incorrect messages
    state))

(def string-builder
  (object/init {:strings []} message-handler))
```

(this is a bit modified version from the test I wrote)

So, we can think of the message handler as a dispatcher that calls the proper
method depending on a message received. Here we have 5 methods.

Let’s try our hello world example:

```clojure
(object/send-msg string-builder {:method :add, :str "Hello"})
(object/send-msg string-builder {:method :add, :str " world"})

(let [result-promise (promise)]
  (object/send-msg string-builder
                   {:method :build
                    :callback (fn [res] (deliver result-promise res))})
  @result-promise)

;; ===> "Hello world"
```

The first two lines are quite straightforward. But what’s going on after?

Our object lives in a separate thread and it’s supposed to return the object
state. So how can we get some result from it? By using callbacks and promises.

Here I decided to use a callback and deliver a promise in it. I don’t think it’s
a good design and I should have used promises right away instead. However, this
is just for demonstration so sue me :)

`@result-promise` is fetching the result of a promise and if it’s not ready, it
waits for it (blocks the current thread).

Now, `add-twice` is a bit more interesting, because it sends messages to
self. One of the problems with this object design is that we can’t really call
other methods from a method, because the object loop deals with one message at a
time. So we can only work with other methods asynchronously. It’s just a
limitation of this architecture and it should be kept in mind or objects can get
stuck.

When I was testing it, I did something like this:

```
1. call :add-twice with "ha" string
2. call :build and see if it equals "haha"
```

and it didn’t work. This is because `:build` message was sent **before**
`:add-twice` sent `:add` messages (it’s a queue, remember?).

I spent quite a bit of time trying to understand what was wrong. That happened
because I am not used to parallel programming and it is a very common
issue. This is one of the reasons why functional programming is getting popular
nowadays — pure functions make it much harder to make a mistake like that. My
state just had a race condition. States are evil ;)

So, that was our foundation of an object system. We can build a lot of things on
top of this. Let’s do classes, shall we?

# Classes

For me, a class is just a template of an object, containing its behaviour
(methods). And, to be honest, classes can be objects themselves (as they are in
Ruby, for example). So let’s introduce some classes.

First, we need to “standardise” how methods are called and executed. I’m getting
lazy so I will just dump the whole namespace here (apologies):

```clojure
(ns functional-oop.klass.method
  (:require [functional-oop.object :as object]))

(defn- call-message [method-name args]
  {:method method-name :args args})

(defn call-on-object [obj method-name & args]
  (object/send-msg obj (call-message method-name args)))

(defn for-message [method-map msg]
  (method-map (:method msg)))

(defn execute [method self state msg]
  (apply method self state (:args msg)))
```

So, a message to call a method is just a hashmap containing two things: method
name and the arguments it should be called with.

Also, take a look at `for-message` function. I am getting a bit ahead of myself
but we will supply classes with hashmaps `name => method` containing
methods. The function `execute` defines the way methods are executed — instead
of accepting message it accepts arguments so we don’t have to think about
messages in our methods.

Handling messages is now quite straightforward:

```clojure

(ns functional-oop.klass
  (:require [functional-oop.object :as object]
            [functional-oop.klass.method :as method]))

(defn- message-handler [method-map]
  (fn [self state msg]
    ;; Ignore invalid messages (at least for now)
    (when-let [method (method/for-message method-map msg)]
      (method/execute method self state msg))))
```

Now, let’s take a look at what classes look like:

```clojure
(defn new-klass [constructor method-map]
  (object/init {:method-map method-map
                :constructor constructor
                :instances []}
               (message-handler {:new instantiate})))
```

As you can see, I decided to create classes as objects. I didn’t have to,
classes could be more abstract concept but I thought it’s just funnier this
way. We could go even further and make `new-klass` function private and create
an object `klass` instead that could create other classes via the method
`:new`. It’s quite simple, actually, but I decided not to push it that far.

Anyway, our klasses are just objects with a state containing methods,
constructor (for initialising new instances) and a vector with instances. We
don’t actually need the vector, but why not.

Now, what is `instantiate` function serving as the method `:new`? Here it is:

```clojure
(defn- instantiate [klass state promise-obj & args]
  (let [{:keys [constructor method-map]} state
        instance (object/init (apply constructor args)
                              (message-handler method-map))]
    (update state :instances conj @(deliver promise-obj instance))))
```

So when we creating a new instance, the constructor is being used for the
initial state and the instance is added to the vector mentioned earlier. The
object is being delivered via promise.

Also, I added a helper function for synchronised instantiation:

```clojure
(defn new-instance
  "Calls :new method on a klass and blocks until the instance is ready. Returns the instance"
  [klass & constructor-args]
  (let [instance-promise (promise)]
    (apply method/call-on-object klass :new instance-promise constructor-args)
    @instance-promise))
```

Okay, let’s try creating a class-oriented string-builder.

```clojure
(defn- constructor [& strings]
  {:strings (into [] strings)})

(def string-builder-klass
  (klass/new-klass
   constructor
   {:add (fn [self state string]
           (update state :strings conj string))
    :build (fn [self state promise-obj]
             (deliver promise-obj
                      (apply str (:strings state)))
             state)
    :free (constantly nil)}))

(def string-builder-1 (klass/new-instance string-builder-klass))
(method/call-on-object instance :add "abc")
(method/call-on-object instance :add "def")
(let [result (promise)]
  (method/call-on-object instance :build result)
  @result)
;; ==> "abcdef

(def string-builder-2 (klass/new-instance string-builder-klass "Hello" " world"))
(method/call-on-object instance :add "!")
(let [result (promise)]
  (method/call-on-object instance :build result)
  @result)
;; ==> "Hello world!"
```

Noice!

# More?

This is just a prototype and it has many flaws (no error handling, objects can
get stuck, memory is leaking). But there are so many things we could
implement. For example, inheritance. Or we could go into the prototype-oriented
way. Another thing we could do is to write a nice DSL for that and it can turn
out to be really nice since we are using Clojure here.

Also, we have mixins available for free already. Mixins are just method maps,
merged in when instantiating a new class.

# Can we build something useful with it?

I made a simple showcase app — TODO list (classic). It has 3 classes: todo list,
todo list item and CLI. You can see the code in the repo (the link is below). I
will just say that it was quite straight-forward. Here’s the console output:

```
# add
Title: Buy lots of toilet paper

# add
Title: Make a TODO list

# list
TODO list:
- Buy lots of toilet paper
- Make a TODO list

# complete
Index: 1

# list
TODO list:
- Buy lots of toilet paper
+ Make a TODO list

# exit
```

# Conclusion

Well, that was interesting (to me). Along the way, I was trying to understand if
that prototype can be translated to Haskell. I can’t say for sure but I think
it’s possible. Haskell has channels, promises and parallelism. Even if it
didn’t, we could always expand on the idea of an object and instantiate objects
as separate processes and send messages with something like RabbitMQ.

For me, the most fascinating thing about programming paradigms is that they are
so different and yet absolutely the same. It’s not about the language; it’s
about the way a programmer thinks. Languages just allow us to code in a certain
style much easier and more productive.

I hope my shabby writing wasn’t completely boring and maybe you even learned
something:)

You can find the repo with the showcase and some tests [here](https://github.com/Nondv/experiments/tree/master/functional_oop).

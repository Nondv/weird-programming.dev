---
title: Programming only in terms of classes
author_profile_url: https://nondv.wtf
categories: [oop]
tags: [ruby, oop, classes, object-oriented programming, pure oop]
description: >-
  What we had an OOP language with NOTHING except classes and variables?
---


In my post [Implementing numbers in "pure" Ruby]({%  post_url 2020-01-17-implementing-numbers-in-pure-ruby %})
I established some ground rules that allowed us to use some basic ruby stuff
like equality operator, booleans, `nil`, blocks and so on.

But what if we had absolutely nothing, even basic operators
like `if` and `while`? Get ready for some pure OOP-madness.


<!--more-->

# Ground rules

- We can define classes and methods.
- We should assume that ruby doesn't have any classes predefined. Imagine we
  start from scratch. Even stuff like `nil` is not available.
- The only operator we can use is the assignment operator (`x = something`).

# No if-operator? Seriously? Even CPUs have it!

Conditionals are important. They are the very essence of logic for our
programs. So how do we do without them? I've come up with a solution:
we can incorporate boolean logic inside EVERY object.

Think about it, in dynamic languages like Ruby logical expressions don't
actually need to evaluate into some "Boolean" class. Instead, they treat
everything as true except for some special cases (`nil` and `false` in Ruby,
`false`, `0` and `''` in JS). So incorporating this logic doesn't seem that
unnatural. But let's dive right into it.


## Basic classes

Let's create a very basic class that will be the ancestor to everything we build
in the future:

```ruby
class BaseObject
  def if_branching(then_val, _else_val)
    then_val
  end
end
```


The method inside is our logical foundation. As you can see, straight away we
assume that any object is true so we return "then-branch".

What about false? Let's start with null, actually.

```ruby
class NullObject < BaseObject
  def if_branching(_then_val, else_val)
    else_val
  end
end
```

Same thing but it returns second parameter.

In Ruby almost every class inherits from `Object` class. However, there's
another class called `BasicObject` which is even higher up in the
hierarchy. Let's copycat this style and introduce our alternative to `Object`:

```ruby
class NormalObject < BaseObject
end
```

Now, everything we define later on should inerit from `NormalObject`. Later on
we can add global helper methods there (like `#null?`).

## If-expressions

This is enough for us to create our if-expressions:

```ruby
class If < NormalObject
  def initialize(bool, then_val, else_val = NullObject.new)
    @result = bool.if_branching(then_val, else_val)
  end

  def result
    @result
  end
end
```

And that's it! I'm serious. It just works.


Consider this example:

```ruby
class Fries < NormalObject
end

class Ketchup < NormalObject
end

class BurgerMeal < NormalObject
  def initialize(fries = NullObject.new)
    @fries = fries
  end

  def sauce
    If.new(@fries, Ketchup.new).result
  end
end

BurgerMeal.new.sauce # ==> NullObject
BurgerMeal.new(Fries.new).sauce # ==> Ketchup
```

You may be wondering, how is that useful if we can't pass any
code blocks around. And what about the "laziness"?

Consider this:

```ruby
# Pseudo-code
if today_is_friday?
  order_beers()
else
  order_tea()
end

# Our If class
If.new(today_is_friday?, order_beers(), order_tea()).result
```

In our example we will order beers AND tea disregarding the day of the
week. This is because arguments are evaluated *before* being passed to the
constructor.

This is very important because without it our programs would be incredibly
inefficient and even invalid.

The solution is to wrap a piece of code in another class. Later on I will refer
to this kind of wrappers as "callable":

```ruby
class OrderBeers
  def call
    # do something
  end
end

class OrderTea
  def call
    # do something else
  end
end

If.new(today_is_friday?, OrderBeers.new, OrderTea.new)
  .result
  .call
```

As you can see, the actual behaviour is not being executed until we explicitly
use `#call`. That's it. This is how we can execute complex code with our `If`
class.

## Booleans (just because we can)

We already have logical values (nulls and everything else) but it would be nice
for expressiveness to add explicit boolean values. Let's do that:

```ruby
class Bool < NormalObject; end

class TrueObject < Bool; end

class FalseObject < Bool
  def if_branching(_then_val, else_val)
    else_val
  end
end
```


Here we have an umbrella class called `Bool`, `TrueObject` with no
implementation (any instance of this object is already considered true) and
`FalseObject` that overrides `#if_branching` in the same way `NullObject` does.

That's it. We implemented booleans. I also added logical NOT operation for
convenience:

```ruby
class BoolNot < Bool
  def initialize(x)
    @x = x
  end

  def if_branching(then_val, else_val)
    @x.if_branching(else_val, then_val)
  end
end
```

As you can see, it just flips parameters for underlying object's `#if_branching`
method. Simple, yet incredibly useful.

## Loops

Okay, another important thing in programming languages is looping. We can
achieve looping by using recursion. But let's implement an explicit `While`
operator.

In general, the `while` operator looks like this:

```ruby
while some_condition
  do_something
end
```

Which could be described like this: "if condition is true, do this and repeat
the cycle again".

The interesting thing to point out is that our condition should be dynamic - it
should be able to change between iterations. "Callables" to the rescue!

```ruby
class While < NormalObject
  def initialize(callable_condition, callable_body)
    @cond = callable_condition
    @body = callable_body
  end

  def run
    is_condition_satisfied = @cond.call
    If.new(is_condition_satisfied,
           NextIteration.new(self, @body),
           DoNothing.new)
      .result
      .call
  end

  # Calls body and then runs While#run again.
  # This way looping is done recursively (too bad no tail-call elimination)
  class NextIteration < NormalObject
    def initialize(while_obj, body)
      @while_obj = while_obj
      @body = body
    end

    def call
      @body.call
      @while_obj.run
    end
  end

  class DoNothing < NormalObject
    def call
      NullObject.new
    end
  end
end
```

# Sample program

Let's create some lists and a function that counts how many nulls in a given
list.


## List

Nothing special here:

```ruby
class List < NormalObject
  def initialize(head, tail = NullObject.new)
    @head = head
    @tail = tail
  end

  def head
    @head
  end

  def tail
    @tail
  end
end
```

We also need a way to walk it (no `#each` + block this time!). Let's create a
class that will be handling it:

```ruby
#
# Can be used to traverse a list once.
#
class ListWalk < NormalObject
  def initialize(list)
    @left = list
  end

  def left
    @left
  end

  # Returns current head and sets current to its tail.
  # Returns null if the end is reached
  def next
    head = If.new(left, HeadCallable.new(left), ReturnNull.new)
             .result
             .call
    @left = If.new(left, TailCallable.new(left), ReturnNull.new)
              .result
              .call
    head
  end

  def finished?
    BoolNot.new(left)
  end

  class HeadCallable < NormalObject
    def initialize(list)
      @list = list
    end

    def call
      @list.head
    end
  end

  class TailCallable < NormalObject
    def initialize(list)
      @list = list
    end

    def call
      @list.tail
    end
  end

  class ReturnNull < NormalObject
    def call
      NullObject.new
    end
  end
end
```

I think the main logic is quite straightforward. We also needed some
helper-runnables for `#head` and `#tail` to avoid null-pointer errors (even
though our nulls aren't actually nulls, we still risk calling a wrong method on
them).

## Counter

This is just an increment that will be used for counting:

```ruby
class Counter < NormalObject
  def initialize
    @list = NullObject.new
  end

  def inc
    @list = List.new(NullObject.new, @list)
  end

  class IncCallable < NormalObject
    def initialize(counter)
      @counter = counter
    end

    def call
      @counter.inc
    end
  end

  def inc_callable
    IncCallable.new(self)
  end
end
```

We don't have any numbers and I decided not to waste time implementing them so I
just used lists instead (see my post on implementing numbers
[here]({%  post_url 2020-01-17-implementing-numbers-in-pure-ruby %})).

An interesting thing to note is `#inc_callable` method. I think if we are to try
and implement our own "language" with those basic classes, it could be a
convention to add methods with `_callable` postfix to return a "callable"
object. This is somewhat like passing functions around in functional
programming.

## Counting nulls in list

First of all we need a null-check. We can incorporate it within `NormalObject`
and `NullObject` as a helper `#null?` (similar to Ruby's `#nil?`):

```ruby
class NormalObject < BaseObject
  def null?
    FalseObject.new
  end
end

class NullObject < BaseObject
  def null?
    TrueObject.new
  end
end
```

Now we can finally implement our null-counter:

```ruby
#
# Returns a counter incremented once for each NullObject in a list
#
class CountNullsInList < NormalObject
  def initialize(list)
    @list = list
  end

  def call
    list_walk = ListWalk.new(@list)
    counter = Counter.new

    While.new(ListWalkNotFinished.new(list_walk),
              LoopBody.new(list_walk, counter))
         .run

    counter
  end



  class ListWalkNotFinished < NormalObject
    def initialize(list_walk)
      @list_walk = list_walk
    end

    def call
      BoolNot.new(@list_walk.finished?)
    end
  end

  class LoopBody < NormalObject
    class ReturnNull < NormalObject
      def call
        NullObject.new
      end
    end

    def initialize(list_walk, counter)
      @list_walk = list_walk
      @counter = counter
    end

    def call
      x = @list_walk.next
      If.new(x.null?, @counter.inc_callable, ReturnNull.new)
        .result
        .call
    end
  end
end
```


And that's it. We can pass any list to it and it will count how many nulls that
list has.


## Conclusion

Object-Oriented Programming is incredibly interesting concept and, apparently,
very powerful. We've, essentially, built a programming language (!) by using
only pure OOP with no additional operators. All we used was class definitions
and variables. Another cool thing is that we have no primitive literals in our
language (e.g. we don't have `null`, instead we just instantiate `NullObject`).
Oh, wonders of programming...


The code is available in my
[experiments](https://github.com/Nondv/experiments/tree/master/only_classes)
repo.

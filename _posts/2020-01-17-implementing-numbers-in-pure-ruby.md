---
title:  Implementing numbers in "pure" Ruby
author_profile_url: https://nondv.wtf
categories: [oop]
tags: [ruby, oop, numbers, object-oriented programming]
description: >-
  Let's implement our own numbers in Ruby without standard library functions
---

*Originaly posted in [carwow blog on medium.com](https://medium.com/carwow-product-engineering/implementing-numbers-in-pure-ruby-1d35ee53ee70)*

Object-Oriented Programming to me means that the system is divided into
objects. An object is just an entity that has some state and some behaviour. You
can make your object do something by sending it a message, hoping that it will
understand you.

For practical reasons, every language has some primitives; basic data types you
can use to write your program. Even though Ruby is, supposedly, a pure OO
language (everything is an object), it has some primitives nevertheless.

For instance, numbers. They look like objects, they have methods and
stuff. However, what are they really? 2 and 3 are different instances of the
Integer class, so they are supposed to have a different state. But what is that
state? Magic.

Let’s try and implement numbers on our own, without magic. Just for fun.

<!--more-->

# Ground rules

So, I came up with this set of constraints:

1. We can’t use any of the basic types except `nil`, `true`, and `false`.
2. No Stdlib (duh).
3. Blocks are ok (just for some expressiveness, they won’t hurt).
4. Using the equality operator for objects is ok. This is to check if two given
   object links point to the same object.
5. Rules do not apply to tests because tests are just there to check if
   something works as intended.
6. Rules do not apply to the `#inspect` method since it serves only for
   demonstration purposes.

Rule #1 is quite controversial. On the one hand, we are using magic
primitives. On the other hand, I think that every program has to have logical
expressions in order for it to be of any use. And we can’t have logical
expressions without “falsey” entities (`nil` and `false`).

I believe we don’t really need `true` and `false` because we can use `nil` for
`false` and any object for `true`. However, why not? Just for expressiveness.

# Implementation idea

One of the things I remember from my time at university is our professor showing
us a way to implement natural numbers in terms of
[Peano axioms](https://en.wikipedia.org/wiki/Peano_axioms) during a set theory
lecture.

Essentially, what we need is:

1. Some basic entity (it will represent zero in the natural numbers set).
2. Some function `next(x)` that returns the number after `x`.

In set theory we can use:

1. Empty set `[]`
2. The function that returns a 1-element set containing its argument:
   `next(s) = [s]`

So our natural numbers are presented as:

- `0 = []`
- `1 = [[]]`
- `2 = [[[]]]`
- ...

The problem is, we don’t have sets at our disposal. Instead of them, we can use
lists.

# List — our basic data structure

```ruby
class List
  # @return [Object]
  attr_reader :head
  # @return [List]
  attr_reader :tail

  EMPTY = new # HACK: at this point constructor hasn't been defined yet

  def initialize(head, tail = EMPTY)
    raise TypeError unless tail.is_a?(List)

    @head = head
    @tail = tail
  end

  def add(obj)
    self.class.new(obj, self)
  end

  def empty?
    self == EMPTY
  end

  def inspect
    return '()' if empty?

    '(' + reduce('') { |a, e| "#{a}, #{e.inspect}" }[2..-1] + ')'
  end
end
```

As you can see, I implemented `List` as a pair. The first element is some object
and the second one is some other list. Notice that lists are immutable.

I decided that every created node **has to** have a tail, except for the empty
list which should be instantiated only once. In order to achieve that I had to
use a hack, which I indicated with a comment.

Now that we have our basic data structure, we can use it instead of sets for our
implementation like this:

- `0 = ()`
- `1 = (())`
- ...

# Natural numbers

Every number object will have an inner list representation as a state. So, the
bare minimum looks like this:

```ruby
class NaturalNumber
  def initialize(list_representation)
    @list_representation = list_representation
  end

  ZERO = new(List::EMPTY)
  ONE = new(List.new(nil, List::EMPTY))
  TWO = new(List.new(nil, List.new(nil, List::EMPTY)))
end
```

But it’s no use to us. We can’t do anything with that. And what’s with all these
`new(...)`? It’s completely impractical!

In order to make this class useful, we need to define some *behaviour*.

## Methods

### Some utility before we start

Let’s add some helper methods to `List`:

```ruby
class List
  def each
    list = self
    until list.empty?
      yield list.head
      list = list.tail
    end

    self
  end

  def reduce(initial_value)
    result = initial_value
    each { |e| result = yield(result, e) }
    result
  end
end
```

These will come in handy later.

Also, we need to have an access to other list representations:

```ruby
class NaturalNumber
  protected
  attr_reader :list_representation
end
```

This is an interesting bit. Not everyone knows that `protected` in Ruby is
different from the one in Java. In Java (and some other languages), protected
methods are only accessible to child classes.

In Ruby, `protected` means that this message can be sent from an object of the
same class:

```ruby
class A
  def test_protected(other)
    other.protected_m
  end
  def test_private(other)
    other.private_m
  end
  protected def protected_m; end
  private def private_m; end
end
a1 = A.new
a2 = A.new
a1.test_protected(a2) # ==> nil
a1.test_private(a2) # ==> NoMethodError
```

### Addition

If we think about it, each actual number equals the nesting level of an empty
list. For 0 the nesting level is zero, 1 wraps an empty list once, 2 does it
twice, and so on. So, to add two numbers we just need to increase the nesting
level of one of them by the nesting level of the other:

```ruby
def +(other)
  NaturalNumber.new(
    other.list_representation.reduce(list_representation) do |list, _|
      list.add(nil)
    end
  )
end
```

### Multiplication

What does `n * 5` mean? It means that we are *adding* `n` with itself five
times. We already have a plus operator. Let’s use it:

```ruby
def *(other)
 other.list_representation.reduce(ZERO) { |a, _| a + self }
end
```

### Comparison operators

Again, we just need to compare the nesting levels:

```ruby
  def ==(other)
    a = list_representation
    b = other.list_representation

    until a.empty? || b.empty?
      a = a.tail
      b = b.tail
    end

    a.empty? && b.empty?
  end

  def <(other)
    list = other.list_representation
    list_representation.each do
      return false if list.empty?
      list = list.tail
    end

    !list.empty?
  end
```

Other operators can be defined in terms of the basic ones:

```ruby
  def <=(other)
    self < other || self == other
  end

  def >(other)
    other < self
  end

  def >=(other)
    other <= self
  end
```

### Subtraction

Subtraction is a tricky one because it’s not defined on the whole set of natural
numbers. You can’t subtract a bigger number from a smaller one.
But it may become useful:

```ruby
  def -(other)
    raise ArgumentError if other > self
    NaturalNumber.new(
      other.list_representation.reduce(list_representation) { |a, _| a.tail }
    )
  end
```

## Usage

Okay, now we have defined basic operations. What next? How do we use them? I
don’t want to initialize numbers with lists every time I need one.

Well, the beauty of it is that by having the number `1` and the `+` operation, we
can create any number we want without having to explicitly provide state:

```ruby
two = NaturalNumber::ONE + NaturalNumber::ONE
three = two + NaturalNumber::ONE

# Don't forget we have multiplication as well!
fifty_four = three * three * three * two
```

As you can see, there can be multiple instances for the same number. But that’s
okay because they are equivalent in terms of usage.

All right. We have natural numbers and we can even do some math with it. But so
what? We need integers!

# Integers

Integers are exactly the same as natural numbers, but for every natural number
they have an additional negative one: -1, -2, -3.

So, that said, we can implement integers by using naturals:

```ruby
class IntegerNumber
  attr_reader :value

  def initialize(natural_number, is_negative = false)
    @value = natural_number
    @is_negative = @value.zero? ? false : is_negative
  end

  ONE = IntegerNumber.new(NaturalNumber::ONE)
  ZERO = IntegerNumber.new(NaturalNumber::ZERO)

  def inspect
    "IntegerNumber<#{'-' if negative?}#{value}>"
  end
end
```

## Methods

I will not bother you with all of them, I will just show a couple to give you an
idea:

```ruby
  # This is the most complicated one
  def +(other)
    return IntegerNumber.new(value + other.value, negative?) if negative? == other.negative?

    if negative?
      if value > other.value
        IntegerNumber.new(value - other.value, true)
      else
        IntegerNumber.new(other.value - value)
      end
    else
      if value > other.value
        IntegerNumber.new(value - other.value)
      else
        IntegerNumber.new(other.value - value, true)
      end
    end
  end

  def ==(other)
    negative? == other.negative? && value == other.value
  end

  def <(other)
    if negative?
      other.negative? ? (value > other.value) : true
    else
      other.negative? ? false : (value < other.value)
    end
  end

  def -@
    IntegerNumber.new(value, !negative?)
  end
```

As you can see, adding an additional element to the state has complicated things
drastically. Even though basic operations were already implemented on natural
numbers, I still had to add a lot of logic on top of it. Big states are bad,
children!

# What's next?

Let’s analyse what we’ve done so far. One of the things I found interesting is
the number of methods inside our classes. It’s an interesting question if the
class `IntegerNumber` has many responsibilities or not.

It really does have a lot of methods. Right now we are facing the “fat models”
problem from Rails. What can we do? We can extract the behaviour to other
classes. I think it’s a good design when data and behaviour are divided. Let’s
try a bit:

```ruby
class IntegerNumber
  class Add
    def self.call(a, b)
      new.call(a, b)
    end

    def call(a, b)
      return IntegerNumber.new(a.value + b.value, a.negative?) if a.negative? == b.negative?

      if a.negative?
        if a.value > b.value
          IntegerNumber.new(a.value - b.value, true)
        else
          IntegerNumber.new(b.value - a.value)
        end
      else
        if a.value > b.value
          IntegerNumber.new(a.value - b.value)
        else
          IntegerNumber.new(b.value - a.value, true)
        end
      end
    end
  end
end
```

The problem here is that we actually have to make `#value` public. It’s
interesting because, on the one hand, we want to make `IntegerNumber` just a
data class, but, on the other hand, we don’t really want to expose its inner
state since it’s so low-level. I guess we just have to make sacrifices or allow
usage of send in Add and all similar classes.

I guess that's one of the main differences between OOP and FP - OOP hides data.

On the bright side, we can introduce some functional programming features to
this design. For example, currying:

```ruby
class IntegerNumber
  class Add
    def self.call(a, b)
      new(a).call(b)
    end

    def initialize(a)
      @a = a
    end

    def call(b)
      ...
    end

    def curry(b)
      new(call(b))
    end
  end
end

add_five = IntegerNumber::Add.new(five)
add_seven = add_five.curry(two)
seven = add_five.call(two)
nine = add_seven.call(two)
```

Without our “ground rules” it would look even better.


# Conclusion

It was an interesting experience because I had some thoughts about software
design in the process. I didn’t prove anything by this nor discovered anything
new. But I had some fun.

You can find the code [here](https://github.com/Nondv/experiments/tree/master/oop_numbers).

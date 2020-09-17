---
title: Implementing integer expressions in Haskell data types
author_profile_url: https://nondv.wtf
categories: [fp]
img: /img/posts/kids_math.png
tags: [haskell, functional programming, fp, data types, pattern matching]
description: >-
  Let's write our own integer expressions language using only data
  types and pattern matching in haskell
---

*Inspired by [Implementing numbers in "pure" Ruby]({%  post_url 2020-01-17-implementing-numbers-in-pure-ruby %})*

When I started working with [Elm programming language](https://elm-lang.org/)
I was amazed how simple and yet powerful the type system is. It's just shocking
how far you can go with with just having some symbols and type constructors.

<!-- Type constructors, in my perception, are merely [injective functions](https://en.wikipedia.org/wiki/Injective_function) -->
<!-- that evaluate into some abstract data we don't, actually, care about (we care -->
<!-- only about the function itself and its arguments). I guess, mathematicians would -->
<!-- disagree with me but that's just how I perceive them to ease the understanding. -->

But how *really* far can we go? Well, I decided to test it out *starting with*
implementing  integers and expressions with them. I decided to use Haskell for
that. Its laziness may be useful.

<!--more-->

# Ground rules

1. Nothing from standard library is being used
2. We can create and use data types
3. We can have **only one** function called `eval` for evaluating our
   expressions.
4. We can use pattern matching.
5. Ground rules can be broken only for the sake of testing the code. For
   example, printing to the console is fine.


# Integer data type

I will use the same ideas I used in my Ruby post. First we implement natural
numbers and then create integers on top of them.

## Natural numbers

<!-- We use elm highlight because haskell's sucks -->

```elm
data NaturalNumber = Zero
                   | Next NaturalNumber
                   deriving Show
```

Following [Peano axioms](https://en.wikipedia.org/wiki/Peano_axioms) we just
establish a zero and every other number will be `n+1`. This is like a list
without data in it.

Now, `deriving Show` just allows REPL to print values of this type. We need it
only to play around with values in the console. We will be adding it to every
data type for this sake.

## Integers

Integers are the same as natural numbers but they also have negatives.

```elm
data Sign = Plus
          | Minus
          deriving Show

data IntNumber = IntNumber Sign NaturalNumber deriving Show
```

so, integer is just a pair of a sign and natural number. We could also
do without `Sign` by doing something like

```
data IntNumber = Negative NaturalNumber
               | Positive NaturalNumber
```


# Expressions

Now, numbers are good but how do we describe int expressions like `5 - (3 + 7)`?


By introducing another data type, of course!

```elm
data Expression = Val IntNumber
                | Dec Expression
                | Inc Expression
                | Neg Expression
                | Add Expression Expression
                | Sub Expression Expression
                | If Expression Expression Expression
                | Equal Expression Expression
                | IsNeg Expression
                | Greater Expression Expression
                | Lower Expression Expression
                deriving Show
```

Now we can write complex expressions via prefix notation:

```elm
zero = Val (IntNumber Plus Zero)
one = Inc zero
two = Inc one
three = Inc two
four = Add two two
five = Add two three

-- or even
If (Greater (Sub five (Add three four)) zero)
 (Add five five)
 (Dec zero)
```


# Evaluation

If you go to haskell repl:

```
$ ghci
Prelude> :load "code.hs"
```

and type `two` you will see something like:

```
Inc (Inc (Val (IntNumber Plus Zero)))
```

True, that equals 2 but how do we get from that to

```
IntNumber Plus (Next (Next Zero))
```

?

Time to implement our function `eval` to evaluate expressions

```hs
eval :: Expression -> IntNumber
eval (Val x) = x
-- ...
```

Now this can unwrap the simplest expression, which is just a number.

## Helpers

Okay, before we continue, I'd like to introduce some functions that will help us
playing with expressions:

```hs
------ repl helpers ------
to_num (IntNumber _ Zero) = 0
to_num (IntNumber Plus (Next x)) = 1 + (to_num (IntNumber Plus x))
to_num (IntNumber Minus (Next x)) = (to_num (IntNumber Minus x)) - 1

eval_num = to_num . eval
```

`to_num` will convert our own integers into haskell integers. This way instead
of long unreadable line

```
IntNumber Plus (Next (Next (Next (Next (Next Zero)))))
```

we will see just `5`. `eval_num` is just a shortcut for `to_num (eval ...)`.

## If

Let's start with `If` (no particular reason, I just like it the most):

```hs
eval (If (Val (IntNumber _ Zero)) _ expr2) = eval expr2
eval (If (Val _) expr1 _) = eval expr1
eval (If cond expr1 expr2) = eval (If (Val (eval cond)) expr1 expr2)
```

We don't have booleans, so we will follow the example of C language and treat
zero as false and anything else as true (we could do it the other way around,
that's not important).

In the first line we match our condition with just a value of zero (the sign
doesn't matter so we put wildcard `_` on it). If we have zero, we just evaluate
the second expression ("else" branch).

The second line says "for any other number evaluate the first ('then') branch".

If the condition is not a simple number, we need to evaluate it first so we put
our expression back with condition evaluated.

Cool? I think so. Let's do `Neg` next. It's simple.

## Neg -- negative value

```hs
eval (Neg (Val (IntNumber Plus n))) = IntNumber Minus n
eval (Neg (Val (IntNumber Minus n))) = IntNumber Plus n
eval (Neg expr) = eval (Neg (Val (eval expr)))
```

Here we just flip around the sign. Nothing fancy.

Note the third expression. We follow the same pattern as we did with `If` -
first we simplify the inner expression and then we follow the logic. This
pattern will appear a lot so I will not comment on it every time.

## Inc -- increment

Alright, now we are getting to actual arithmetics.

As we have seen with natural numbers, we can do a lot with a simple +1
operation. Let's implement it:

```hs
eval (Inc (Val (IntNumber _ Zero))) = IntNumber Plus (Next Zero)
eval (Inc (Val (IntNumber Plus n))) = IntNumber Plus (Next n)
eval (Inc (Val (IntNumber Minus (Next n_minus_one)))) = IntNumber Minus n_minus_one
eval (Inc expr) = eval (Inc (Val (eval expr)))
```

The first line is concerned with zeroes and is similar to the one in `If`.

The second line is for the simplest case of positive numbers. We just increment
the natural number.

The third line is a bit more interesting. It's concerned with negative
numbers. What happens to a negative number when we add one to it? Its absolute
value (natural number) gets decreased by one. We can't express -1 operation in
terms of data but pattern matching allows us to destructure the data.
So `n = (Next n_minus_one) => (Dec n) = n_minus_one`.

So elegant <3.

## Dec -- decrement

The decrement is the opposite of the increment.

```hs
eval (Dec (Val (IntNumber _ Zero))) = IntNumber Minus (Next Zero)
eval (Dec (Val (IntNumber Plus (Next n_minus_one)))) = IntNumber Plus n_minus_one
eval (Dec (Val (IntNumber Minus n))) = IntNumber Minus (Next n)
eval (Dec expr) = eval (Dec (Val (eval expr)))
```

## Add -- addition

Now, imagine you have two boxes of apples. How do we add apples from the second
one to the first? We can just manually move them one by one until the second box
is empty.

```hs
eval (Add expr1 (Val (IntNumber _ Zero))) = eval expr1
eval (Add expr1 (Val (IntNumber Plus n))) = eval (Add (Inc expr1) (Dec (Val (IntNumber Plus n))))
eval (Add expr1 (Val (IntNumber Minus n))) = eval (Add (Dec expr1) (Inc (Val (IntNumber Minus n))))
eval (Add expr1 expr2) = eval (Add expr1 (Val (eval expr2)))
```

Adding zero changes nothing, so we just proceed with the first "box"
(argument). Now we have two cases left: when the second number is positive and negative.

For positive numbers we just increment the first expression and decrement the
second, exactly like with apples. For negative numbers it's the other way
around.

## Sub -- substraction

Substraction is just like adding negative second argument to the first:

```hs
eval (Sub expr1 expr2) = eval (Add expr1 (Neg expr2))
```

We defined some operations in terms of already existing ones. Noice!

## Equal -- equality comparision

In our "language" it's quite easy to define comparison operators, because we
have numbers instead of booleans.

If we substruct `x` from `x` the result will be zero. We can use that:

```hs
eval (Equal expr1 expr2) = eval (If (Sub expr1 expr2)
                                 (Val (IntNumber Plus Zero))
                                 (Val (IntNumber Plus (Next Zero))))
```

If expression! So beautiful! We could also use `let` to name the branches
`false` and `true` respectively.

## IsNeg -- negativity check

Before we move on to `>` and `<` operators I'd like to introduce this predicate.
It will be helpful to us because other comparison operators will use the same
substraction idea.

```hs
eval (IsNeg (Val (IntNumber _ Zero))) = IntNumber Plus Zero
eval (IsNeg (Val (IntNumber Plus _))) = IntNumber Plus Zero
eval (IsNeg (Val (IntNumber Minus _))) = IntNumber Plus (Next Zero)
eval (IsNeg expr) = eval (IsNeg (Val (eval expr)))
```

Zero is not negative so we return zero (false). Positive numbers aren't either,
hence, zero again. Negative numbers are negative (surprise!) so we return
anything else (1 in this case).


## Greater and Lower comparison operators

If we substruct `b` from `a` the sign of the result will tell us how they
compare to each other. If `a` is greater, a positive number will be returned,
otherwise, negative.

Lower is just a different direction. Tomayto, tomahto.

```hs
eval (Greater expr1 expr2) = eval (IsNeg (Sub expr2 expr1))
eval (Lower expr1 expr2) = eval (Greater expr2 expr1)
```

## More?

We could also implement logical operators `And`, `Or` and `Xor`. But they are
quite straightforward so I can't be bothered.

# Conclusion

Well, this is only the tip of an iceberg. We implemented integers by using only
data types and pattern matching.

By the way, have you noticed how similar the code looks to Lisp? The only
difference is it lacks outer pair of parens.

```hs
zero = Val (IntNumber Plus Zero)
one = Inc zero
two = Inc one
three = Add one two
four = Add two two
five = Add two three

eval_num (If (Greater one zero)
           (If (Lower (Sub five (Neg five)) zero)
             one
             (Dec zero))
           zero)
```

could be written in Emacs Lisp:

```elisp
(if (> 1 0)
  (if (< (- 5 (- 5)) 0)
    1
    (1- 0)))
```

and the result is -1.

That was fun. Lots more to try though. I am planning to push this idea even
further but maybe some other time.

[Complete source code](https://github.com/Nondv/experiments/blob/master/integer_expressions_in_haskell/code.hs).

---
title: Getting rid of OOP in Javascript with lodash/fp
author_profile_url: https://nondv.wtf
categories: [javascript, fp]
tags: [javascript, js, oop, fp, lodash, lodash/fp]
img: /img/posts/lambda.svg
description: >-
  Trying to make my code more consistent and to make it feel more FP-like.
---

One of the things I dislike about JavaScript is how it intertwines
object-oriented paradigm with functional programming. Ironically, that's also the
thing that I do like about JS. I like that I have a choice and JS actually does
allow you to write functional code that looks natural (as opposed to Ruby that
doesn't even have actual functions per se).

However, the standard library in JavaScript is written in a OOP manner, meaning
that you need to call methods on objects instead of using functions. This
creates inconsistency when you write in functional style because you end up with
code that uses both functions end methods: `getUsers(ids).map(userToJson)`.

I'd much rather prefer to have a consistent function-oriented code. Lodash,
defining a lot of commonly-used functions, basically provides functional
alternative to JS methods from standard library.

<!--more-->

# What is lodash?

Basically, lodash is just a library that provides a lot of utility
functions. Years ago JavaScript was in much worse shape than it is now so lodash
(which was a fork of Underscore.js) filled in a lot of gaps in standard
library.

Nowadays a lot of functions in it seem obsolete with JS evolved so much over the
years. But the reality is, the language is still a mess (for instance, are you
aware of which version of the language your most recent webpack project uses?)
and lodash is quite stable.

Plus, even tho it gets better and better, JS still lacks a lot of useful
functions, e.g. `orderBy`. Yes, in most cases those functions are really simple
and anyone can implement them on their own. But the truth is, it's good when you
don't have to write them by yourself all the time. Lodash collects them in one
place; it's stable; and it's, most likely, already in your project even if you
don't use it directly.

# What is lodash/fp?

[Lodash/fp](https://github.com/lodash/lodash/wiki/FP-Guide) provides the most of
the original lodash functions but modified to promote functional style.

For example, some functions have been aliased to more common (I guess?) names,
e.g. `flow` was aliased to `pipe` (like pipe operator in Elixir, for example).

Another thing is many (or all?) functions allow
[currying](https://en.wikipedia.org/wiki/Currying). This is very nice because it
allows you to write shorter and more expressive code.

Also parameter order is different in lodash/fp. Now functional arguments come
first and data arguments come last. For example, compare original lodash
`map(arr, f)` with lodash/fp `map(f, arr)`.

This was done to get the most out of currying. Compare:

```js
// lodash
const ageFilter = users => filter(users, u => u.age > 18);

// lodash/fp
const ageFilter = filter(u => u.age > 18);
```

# Some common cases


## Pipe operator

Pipe operator is a great way to express a computation because instead of a
complicated expression involving lots of nested functions, you can write your
computation as a list of transformations (functions) that are being called in
order.

Lodash doesn't *really* define it however it has compose functions `flow` and
`flowRight`:

```js
// Simple
const getBankByUserId = id => getUserBank(getUser(id));
const bank = getBankByUserId(userId);

// flowRight - most common function composition h(x) = f*g(x) = f(g(x))
// it's also aliased to `compose` in lodash/fp
const getBankByUserId = flowRight([getUserBank, getUser])
const bank = getBankByUserId(userId);

// flow - same as flowRight but in a reverse order
const getBankByUserId = flow([getUser, getUserBank])
const bank = getBankByUserId(userId);
```

Now, this is, basically, what a pipe operator would do, it composes functions
but also calls the result with a value. So all we have to do is to call our
composition:

```js
// sendEmail(message, getContacts(getUser(getUserId(transaction))).email)

flow([
  getUserId,
  getUser,
  getContacts,
  c => sendEmail(message, c.email),
])(transaction);
```

I, personally, hate that the value we are transforming comes in the very
end. What if there're *a lot* of transformations? It's not very nice to have the
actual value so far down. I came up with a simple hack: call the function
without arguments but the first function should return the value itself. Take a
look at the final snippet:

```js
import pipe from 'lodash/fp/pipe'

pipe([
  () => transaction,
  getUserId,
  getUser,
  getContacts,
  c => sendEmail(message, c.email),
])();
```

Here's another hack for you. You can inject a console.log anywhere in the
pipeline to see what's going on after some step. Check the diff:

```
  import pipe from 'lodash/fp/pipe'

  pipe([
    () => transaction,
    getUserId,
    getUser,
+   x => { console.log('USER:', x); return x },
    getContacts,
    c => sendEmail(message, c.email),
  ])();
```

## Collection processing (map, reduce, filter, etc...)


As I've mentioned before, they are all curried and their parameters have a
different order from their original `lodash` counterparts. However, if you have
experience with functional languages (e.g. Clojure, Haskell, Elm) you will feel
right at home.

Just take look at the snippet:

```js
import pipe from 'lodash/fp/pipe'
import map from 'lodash/fp/map'
import reduce from 'lodash/fp/reduce'
import toPairs from 'lodash/fp/toPairs'
import sortBy from 'lodash/fp/sortBy'
import take from 'lodash/fp/take'
import last from 'lodash/fp/last'

const topFiveUserArtists = pipe([
  () => getUser(userId),
  getUserSongs,
  map(song => [song.artist, getNumberOfPlays(song, userId)]),
  reduce((obj, ([artist, plays])) => ({ ...obj, [artist]: (obj[artist] || 0) + plays }), {}),
  toPairs,
  sortBy(last),
  take(5),
])();
```

Another approach:

```js
import pipe from 'lodash/fp/pipe'
import groupBy from 'lodash/fp/groupBy'
import sumBy from 'lodash/fp/sumBy'
import mapValues from 'lodash/fp/mapValues'
import toPairs from 'lodash/fp/toPairs'
import sortBy from 'lodash/fp/sortBy'
import take from 'lodash/fp/take'
import last from 'lodash/fp/last'

const topFiveUserArtists = pipe([
  () => getUser(userId),
  getUserSongs,
  groupBy(s => s.artist),
  mapValues(sumBy(song => getNumberOfPlays(song, userId))),
  toPairs,
  sortBy(last),
  take(5),
])();

```

I, personally, prefer the first one as it uses less specific functions and just
relies on the essentials. But yeah, lodash has a lot of cool utility functions
like `mapValues`. Also, I import each function separately. This is my personal
preference and it, supposedly, reduces the bundle size when webpack has
finished.

## Some misc. utilities (with JS analogs)

- `range(a, b)` = `[...Array(b - a).keys()].map(i => a + i)`
- `take(n, arr)` = `arr.slice(0, n)`
- `isEqual(a, b)`. JS doesn't have any alternatives included. It performs deep
  equality checks (meaning that it will compare objects and arrays value by
  value, not by reference).
- `isEmpty(coll)` = `coll.length == 0` for arrays but `isEmpty` is more powerful
  as it works with arrays, objects, sets, etc.
- `uniq(arr)` = `[...new Set(arr)]` but `uniq` also preserves order.
- `sortBy(f, arr)` = `[...arr].sort((a, b) => f(a) < f(b) ? -1 : 1)` (`[...arr]`
  is for cloning).
- `tail(arr)` (careful, don't confuse with `rest`) = `arr.slice(1)`


# Conclusion

By using this DSL we are able to get rid of the most object-oriented code. It
becomes better-structured, more consistent, and even a bit safer (bc some
standard JS methods are actually mutating data, e.g. `Array#sort`).

For me personally the result code looks a lot like Clojure which I adore.

Another advantage is that using a third-party library instead of the standard
library frees you from runtime/language headache. You don't have to think about
your runtime or webpack having stuff implemented anymore.

Plus, it provides solutions for many common use-cases. I, actually, get annoyed
when I want to use some small utility function I or my teammate wrote but only
to find out that it's defined in a different  project and I have to copy-paste
it from there.

If you get your team consistently use a DSL like that, your whole codebase
should become healthier (I *think*). Apparently, there're other options apart
from lodash.

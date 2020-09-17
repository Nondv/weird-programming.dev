---
title: Sleep sort algorithm
author_profile_url: https://url-to-the-author
categories: [algorithms]
tags: [sleep sort, sorting, algorithm]
img: /img/posts/sleeping.png
description: >-
  Fun and creative concurrent sorting algorithm
---

Some time ago I was doing some small introductions to basic algorithms I learned
back in school to my colleagues at carwow (just for fun).
Some of them became [posts on medium](https://medium.com/programming-basics).

After one of them a colleague told me about sleep sort algorithm. I think it's
ingenious and should be in a blog calling itself "weird programming".

<!--more-->

# Algorithm

The idea is simple and brilliant. Imagine you have a list of numbers you want to
sort.

1. Create a separate thread for *every* element in the list.
2. In each thread for a corresponding number `x` sleep for `x` seconds.
3. After that print `x`.

After every thread has finished you will have a sorted list printed out. This
works because lesser `x`'s will be "asleep" for shorter periods of time.

Obviously, you don't have to sleep seconds and you don't have to print them out,
instead you could push them to stack or something.

# Clojure implementation

```clojure
(defn sleep-sort [multiplier coll]
  (let [result-atom (atom [])
        futures (doall (map
                        #(future (Thread/sleep (* % multiplier))
                                 (swap! result-atom conj %))
                        coll))]
    (run! deref futures)
    @result-atom))
```

With `multiplier` equal to 1000 the algorithm will sleep `x` seconds.

Quite straightforward implementation, for data storage an
[atom](https://clojure.org/reference/atoms) is used. For threading I used
[future](https://clojuredocs.org/clojure.core/future).

The only weird thing here (imho) is the line `(run! deref futures)`. This is to
make sure that all threads are finished before returning the value stored in the
atom.


# Go implementation

```go
func sort(array []int, d time.Duration) []int {
	result := make([]int, len(array))
	ch := make(chan int, len(array))
	for i := 0; i < len(array); i++ {
		go func(x int) {
			time.Sleep(time.Duration(x) * d)
			ch <- x
		}(array[i])
	}
	for i := 0; i < len(array); i++ {
		result[i] = <-ch
	}
	return result
}
```

Go is destined to be used as a concurrent procedural language. I really like
this solution even though it's incredibly wordy.

The program just iterates over the array and creates a goroutine for each
element. Each goroutine pushes valuess into the channel. Classic.

We could also write the same code in Clojure, btw (using
[core.async](https://clojuredocs.org/clojure.core.async) library)


# Ruby implementation

Ruby is my core skill so I couldn't leave it out.

```ruby
def sleep_sort(array, multiplier)
  result = []
  threads = array.map do |x|
    Thread.new do
      sleep(x * multiplier)
      result.push(x)
    end
  end
  threads.each(&:join)
  result
end
```

Yep, just a thread per number, pushing to an array, waiting until all threads
are finished.

Ruby doesn't have a true parallelism though. It remains single-threaded. But
since we use IO-blocking operation (sleep) the interpeter is able to switch
between ruby threads.

# Performance and tuning

Unfortunately, this algorithm heavilly relies on input data limits.

For example, we could make it faster by using multiplier of 100 instead
of 1000. However, for large arrays we would have to understand that the last
thread will be spawned much later than the first one.

Another thing is the range the numbers are in. If your numbers are in 1..100
than you would want to use a bigger multiplier. And the other way around, if
your numbers are in 1000...1000000 you don't need big ones.

Also the solutions I wrote do not work with negative numbers. For them we could
create a separate datastructure and join them later. Or we could juts use adding
elements to beginning/end depending on the sign:)

# Final thoughts

This algorithm is completely impractical. However, I think the person who's come
up with it is a genius. It's incredibly creative and resourceful. I wish I had a
brain that can come up with something simple and cool as this.

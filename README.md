[![Gem Version](https://badge.fury.io/rb/proxified.svg)](https://badge.fury.io/rb/proxified)

# Proxified

A simple way to put a proxy in front of any object, at any time.

You can add and remove a proxy to and from any object instance methods and inherit or change the behavior down the class hierarchy.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'proxified'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install proxified

## Usage

You have two options to *proxify* and *unproxify* objects:

  * *statically*: if you want to put a proxy on a class while defining it, just `include Proxified` and call `proxify` with the method(s) you want to *proxify* and the code you want to run.
     When you want to remove a proxy, just call `unproxify` with the method(s) you want to *unproxify*, or without methods if you want to *unproxify* all *proxified* methods.
     To check if a given method is *proxified*, call `proxified?` with the method name, or without arguments to check if any instance method is *proxified*.

  * *dynamically*: if you want to put a proxy on a class at runtime, or on a single object without affecting its class, call `Proxify` with the class/object and the method(s) you want to *proxify*.
     Similarly, use `Unproxify` and `Proxified?` with the class/object and the method(s) you want to *unproxify*/*check*.

You can also mix the two approaches! (see the examples below)

In order not to change the class interface, a method is only *proxified* when the corresponding instance method is defined (before or after the proxy definition).
Similarly, a *proxified method* is removed whenever the corresponding instance method is removed from the class.

Moreover, the *proxified methods* take the arguments specified by the block, so it should take the same arguments as the original methods.
Finally, it's possible to call the actual methods invoking `super` inside the block.

```ruby

require 'proxified'

# Static proxy:

class A
  include Proxified

  proxify :foo, :bar, :biz do
    "proxified #{super()}"
  end

  def foo; 'foo'; end

  def bar; 'bar'; end

  def biz; 'biz'; end

  def baz; 'baz'; end
end

A.ancestors # => [A::Proxy, A, Proxified, ...]

a1, a2 = A.new, A.new

a1.foo # => 'proxified foo'
a2.foo # => 'proxified foo'
a1.bar # => 'proxified bar'
a2.bar # => 'proxified bar'
a1.biz # => 'proxified biz'
a2.biz # => 'proxified biz'
a1.baz # => 'baz'
a2.baz # => 'baz'


# unproxify the :foo method
A.unproxify(:foo)  # => [:foo]

# the :foo method is not proxified anymore
A.proxified?(:foo) # => false
# A is still proxified, i.e. it has at least one proxified method
A.proxified?       # => true

a1.foo # => 'foo'
a2.foo # => 'foo'
a1.bar # => 'proxified bar'
a2.bar # => 'proxified bar'
a1.biz # => 'proxified biz'
a2.biz # => 'proxified biz'
a1.baz # => 'baz'
a2.baz # => 'baz'


# unproxify all the methods
A.unproxify  # => [:bar, :biz]

# A is not proxified anymore
A.proxified? # => false

a1.foo # => 'foo'
a2.foo # => 'foo'
a1.bar # => 'bar'
a2.bar # => 'bar'
a1.biz # => 'biz'
a2.biz # => 'biz'
a1.baz # => 'baz'
a2.baz # => 'baz'


# Dynamic proxy:

# on a class
Proxify(A, :foo, :bar) { 'proxified again' } # => [:foo, :bar]

a1.foo # => 'proxified again'
a2.foo # => 'proxified again'
a1.bar # => 'proxified again'
a2.bar # => 'proxified again'
a1.biz # => 'biz'
a2.biz # => 'biz'
a1.baz # => 'baz'
a2.baz # => 'baz'


# on a single object
Proxify(a1, :bar, :biz) { 'singleton proxy' } # => [:bar, :biz]

a1.foo # => 'proxified again'
a2.foo # => 'proxified again'
a1.bar # => 'singleton proxy'
a2.bar # => 'proxified again'
a1.biz # => 'singleton proxy'
a2.biz # => 'biz'
a1.baz # => 'baz'
a2.baz # => 'baz'


# unproxify all the methods of a1
Unproxify(a1)  # => [:foo, :bar, :biz]

# still proxified because of the class' proxy
Proxified?(a1) # => true

a1.foo # => 'proxified again'
a2.foo # => 'proxified again'
a1.bar # => 'proxified again'
a2.bar # => 'proxified again'
a1.biz # => 'biz'
a2.biz # => 'biz'
a1.baz # => 'baz'
a2.baz # => 'baz'


# unproxify all the methods of A
Unproxify(A, :foo, :bar)  # => [:foo, :bar]

a1.foo # => 'foo'
a2.foo # => 'foo'
a1.bar # => 'bar'
a2.bar # => 'bar'
a1.biz # => 'biz'
a2.biz # => 'biz'
a1.baz # => 'baz'
a2.baz # => 'baz'

```

Just look at the code documentation to see more examples of what you can/cannot do.

## Notes

This is my first gem, something I extracted from a bigger project and a first attempt to give something back to the community.

Any constructive feedback is welcome and appreciated, thank you!

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/vtsl01/proxified. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Proxified project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/vtsl01/proxified/blob/master/CODE_OF_CONDUCT.md).

# Proxified

Proxify any object with a few lines of code.

A simple way to add (and remove) a proxy to any object's instance methods and to inherit and change the behaviour down the class hierarchy.

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

Just `include Proxified` in your class and call `proxify` with the method(s) you want to proxify and the code you want to run.

If you want to remove a proxy, just call `unproxify` with the method(s) you want to unproxify.

In order to not change the class interface, a method is only `proxified` when the corresponding instance method is defined (before or after the proxy definition).
Similarly, a `proxified method` is removed whenever the corresponding instance method is removed from the class.

Moreover, the `proxified methods` take the arguments specified by the `block`, so it should take the same arguments as the original `methods`.
Finally, it's possible to call the actual `methods` invoking `super` inside the `block`.

```ruby

require 'proxified'

# Basic usage:
class A
  include Proxified

  proxify :welcome, :goodbye do |name|
    check(name)
    super(name)
  end

  def check(name)
    puts "checking #{name}"
  end

  def welcome(name)
    puts "hello #{name}!"
  end

  def goodbye(name)
    puts "goodbye #{name}!"
  end
end

a = A.new
a.welcome('jack') => 'checking jack'; 'welcome jack!';
a.goodbye('jack') => 'checking jack'; 'goodbye jack!';
a.welcome         => raises ArgumentError
a.check('jack')   => 'checking jack' # not proxified

# Unproxifing a proxified method:
class B < A
  unproxify :welcome
end

b = B.new
b.welcome('jack') => 'welcome jack!';
b.goodbye('jack') => 'checking jack'; 'goodbye jack!';


# Redefining a proxified method:
class C < A
  def welcome(name)
    puts "welcome #{name.upcase}!"
  end
end

c = C.new
c.welcome('jack') => 'checking jack'; 'welcome JACK!';
c.goodbye('jack') => 'checking jack'; 'goodbye jack!';


# Reproxifing a proxified method:
class D < A
  proxify :welcome do |name|
    super(name.upcase)
  end
end

d = D.new
d.welcome('jack') => 'checking JACK'; 'welcome JACK!';
d.goodbye('jack') => 'checking jack'; 'goodbye jack!';


# Reproxifing and redefining a proxified method:
class E < A
  proxify :welcome do |name|
    super(name.upcase)
  end

  def welcome(name)
    puts "hello #{name}!"
  end
end

e = E.new
e.welcome('jack') => 'hello JACK!';
e.goodbye('jack') => 'checking jack'; 'goodbye jack!';


# Redefining a proxified method to call super:
class F < A
  def welcome(name)
    # Will call F's proxy, then A's proxy and finally A's method
    super(name)
    puts 'hi'
  end
end

f = F.new
f.welcome('jack') => 'checking jack'; 'checking jack'; 'welcome jack!'; 'hi';
f.goodbye('jack') => 'checking jack'; 'goodbye jack!';
```
## Notes

This is my first gem, something I extracted from a bigger project and a first attempt to give back something to the community.

Any constructive feedback is welcome and appreciated, thank you!

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/vtsl01/proxified. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Proxified project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/vtsl01/proxified/blob/master/CODE_OF_CONDUCT.md).

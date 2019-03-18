# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext'

# Allows to _proxify_ and _unproxify_ any instance method of a class with
# custom code and to inherit and change the behaviour down the class hierarchy.
#
# The global methods allow to dinamically _proxify_ and _unproxify_ a class or
# an object injecting Proxified in the class or the object's singleton class.
#
# This makes possible to dinamically wrap a proxy around any class with no need
# for the class to know it, and to change the behaviour of one or more objects
# without side effects on other objects of the same class.
module Proxified
  extend ::ActiveSupport::Concern

  included do
    # Stores the methods to _proxify_ allowing descendants to override them
    # without affecting the parent.
    class_attribute :proxified_methods, default: {}, instance_accessor: false
  end

  class_methods do
    # For each +method+ in +methods+, defines a _proxified_ _method_ that
    # runs the given +block+ when +method+ is called, or raises ArgumentError
    # if no +block+ or no +methods+ are given.
    #
    # In order not to change the class interface, a method is only _proxified_
    # when the corresponding instance method is defined (before or after the
    # proxy definition), while a _proxified_ _method_ is removed whenever the
    # corresponding instance method is removed from the class. Moreover, the
    # _proxified_ _methods_ take the arguments specified by the +block+, so the
    # +block+ should take the same arguments as the original +methods+.
    # Finally, it's possible to call the original +methods+ invoking +super+
    # inside the +block+.
    #
    # The _proxified_ _methods_ are defined in a proxy module that is
    # automatically prepended to the class only the first time a _proxified_
    # _method_ is defined within that class. In this way, descendants who
    # redefine a _proxified_ _method_ get their own proxy module, while those
    # who do not redefine a _proxified_ _method_ get the parent's proxy module.
    #
    # Beware: if a child redefines a _proxified_ _method_ to call +super+, the
    # parent's _proxified_ _method_ will be called.
    #
    # ======Examples
    #
    # Basic usage:
    #   class A
    #     include Proxified
    #
    #     proxify :welcome, :goodbye do |name|
    #       check(name)
    #       super(name)
    #     end
    #
    #     def check(name)
    #       puts "checking #{name}"
    #     end
    #
    #     def welcome(name)
    #       puts "welcome #{name}!"
    #     end
    #
    #     def goodbye(name)
    #       puts "goodbye #{name}!"
    #     end
    #   end
    #
    #   A.ancestors       # => [A::Proxy, A, Proxified, ...]
    #
    #   a = A.new
    #   a.welcome('jack') # => 'checking jack'; 'welcome jack!';
    #   a.goodbye('jack') # => 'checking jack'; 'goodbye jack!';
    #   a.welcome         # => raises ArgumentError
    #   a.check('jack')   # => 'checking jack' (not proxified)
    #
    #
    # Just inheriting:
    #   class B < A; end
    #
    #   B.ancestors       # => [B, A::Proxy, A, Proxified, ...]
    #
    #   b = B.new
    #   b.welcome('jack') # => 'checking jack'; 'welcome jack!';
    #   b.goodbye('jack') # => 'checking jack'; 'goodbye jack!';
    #
    #
    # Inheriting and redefining a _proxified_ _method_:
    #   class C < A
    #     def welcome(name)
    #       puts "welcome #{name.upcase}!"
    #     end
    #   end
    #
    #   C.ancestors       # => [C::Proxy, C, A::Proxy, A, Proxified, ...]
    #
    #   c = C.new
    #   c.welcome('jack') # => 'checking jack'; 'welcome JACK!';
    #   c.goodbye('jack') # => 'checking jack'; 'goodbye jack!';
    #
    #
    # Inheriting and _reproxifing_ a _proxified_ _method_:
    #   class D < A
    #     proxify :welcome do |name|
    #       super(name.upcase)
    #     end
    #   end
    #
    #   D.ancestors       # => [D::Proxy, D, A::Proxy, A, Proxified, ...]
    #
    #   d = D.new
    #   d.welcome('jack') # => 'checking JACK'; 'welcome JACK!';
    #   d.goodbye('jack') # => 'checking jack'; 'goodbye jack!';
    #
    #
    # Inheriting, _reproxifing_ and redefining a _proxified_ _method_:
    #   class E < A
    #     proxify :welcome do |name|
    #       super(name.upcase)
    #     end
    #
    #     def welcome(name)
    #       puts "hello #{name}!"
    #     end
    #   end
    #
    #   E.ancestors       # => [E::Proxy, E, A::Proxy, A, Proxified, ...]
    #
    #   e = E.new
    #   e.welcome('jack') # => 'hello JACK!';
    #   e.goodbye('jack') # => 'checking jack'; 'goodbye jack!';
    #
    #
    # Inheriting and redefining a _proxified_ _method_ to call +super+:
    #   class F < A
    #     def welcome(name)
    #       super(name)
    #       puts 'hi'
    #     end
    #   end
    #
    #   F.ancestors       # => [F::Proxy, F, A::Proxy, A, Proxified, ...]
    #
    #   f = F.new
    #   f.welcome('jack') # => 'checking jack'; 'checking jack'; 'welcome jack!'; 'hi';
    #   f.goodbye('jack') # => 'checking jack'; 'goodbye jack!';
    def proxify(*methods, &block)
      raise ArgumentError, 'no block given' unless block_given?
      raise ArgumentError, 'no methods given' if methods.empty?

      methods.each do |method|
        self.proxified_methods = proxified_methods.merge(method => block)
        add_proxy_method(method) if method_defined?(method)
      end
    end

    # Unproxifies the given +methods+ removing them from the proxy module. If no
    # +methods+ are given, all the _proxified_ _methods_ are removed.
    #
    # ======Examples
    #
    #   class A
    #     include Proxified
    #
    #     proxify :foo, :bar, :biz do
    #       super().upcase
    #     end
    #
    #     def foo
    #       'foo'
    #     end
    #
    #     def bar
    #       'bar'
    #     end
    #
    #     def biz
    #       'biz'
    #     end
    #   end
    #
    #   A.unproxify(:foo)
    #   a.foo # => 'foo;
    #   a.bar # => 'BAR'
    #   a.biz # => 'BIZ'
    #
    #   A.unproxify
    #   a.foo # => 'foo;
    #   a.bar # => 'bar'
    #   a.biz # => 'biz'
    def unproxify(*methods)
      methods = proxified_methods.keys if methods.empty?

      self.proxified_methods = proxified_methods.except(*methods)

      methods.each { |method| remove_proxy_method(method) }
    end

    # If given no +method+, checks whether any instance method is _proxified_,
    # otherwise it checks for the given +method+.
    #
    # ======Examples
    #
    #   class A
    #     include Proxified
    #
    #     proxify :foo, :bar do |name|
    #       super().upcase
    #     end
    #
    #     def foo
    #       'foo'
    #     end
    #
    #     def bar
    #       'bar'
    #     end
    #
    #     def biz
    #       'biz'
    #     end
    #   end
    #
    #   A.proxified?       # => true
    #   A.proxified?(:foo) # => true
    #   A.proxified?(:bar) # => true
    #   A.proxified?(:biz) # => false
    #
    #   A.unproxify(:foo)
    #   A.proxified?       # => true
    #   A.proxified?(:foo) # => false
    #   A.proxified?(:bar) # => true
    #   A.proxified?(:biz) # => false
    #
    #   A.unproxify(:bar)
    #   A.proxified?       # => false
    #   A.proxified?(:foo) # => false
    #   A.proxified?(:bar) # => false
    #   A.proxified?(:biz) # => false
    def proxified?(method = nil)
      method.nil? ? proxified_methods.any? : method.in?(proxified_methods)
    end

    private

    # Adds the +method+ to the proxy only if it has been proxified.
    def method_added(method) # :nodoc:
      # Don't do nothing if the attribute is not defined and initialized yet
      return unless respond_to?(:proxified_methods) && proxified_methods?

      add_proxy_method(method) if proxified?(method)
    end

    # Unproxifies the +method+ only if it has been proxified.
    def method_removed(method) # :nodoc:
      # Don't do nothing if the attribute is not defined and initialized yet
      return unless respond_to?(:proxified_methods) && proxified_methods?

      unproxify(method) if proxified?(method)
    end

    # Defines the +method+ in the proxy module.
    def add_proxy_method(method) # :nodoc:
      # Redefine to avoid warnings if the method has already been defined
      proxy.redefine_method(method, &proxified_methods[method])
    end

    # Removes the +method+ from the proxy module.
    def remove_proxy_method(method) # :nodoc:
      proxy.remove_method(method) if proxy.method_defined?(method)
    end

    # Returns the proxy module prepending it only if it's not already present
    # in this class.
    def proxy # :nodoc:
      return const_get('Proxy', false) if const_defined?('Proxy', false)

      const_set('Proxy', Module.new).tap { |proxy| prepend proxy }
    end
  end
end

# Injects Proxified in the +receiver+ and _proxifies_ the given +methods+, or
# raises ArgumentError if no +block+ or no +methods+ are given.
#
# +receiver+ can be a class or an ordinary object.
#
# If +receiver+ is a class, it is equivalent to including Proxified and calling
# .proxify.
#
# If +receiver+ is an object, Proxified is injected in its singleton class and
# other objects of the same class will not be affected.
#
# If +receiver+ is an object of a _proxified_ class, the class' proxy is
# overridden but other objects of the class will not be affected.
#
# See Proxified.proxify for further details.
#
# ======Examples
#
# _Proxifying_ a class:
#   class A
#     def foo
#       'foo'
#     end
#
#     def bar
#       'bar'
#     end
#   end
#
#   a1, a2 = A.new, A.new
#
#   Proxify(A, :foo) { super().upcase }
#   a1.foo # => 'FOO'
#   a2.foo # => 'FOO'
#   a1.bar # => 'bar'
#   a2.bar # => 'bar'
#
#
# _Proxifying_ an object:
#   class B
#     def foo
#       'foo'
#     end
#
#     def bar
#       'bar'
#     end
#   end
#
#   b1, b2 = B.new, B.new
#
#   Proxify(b1, :foo) { super().upcase }
#   b1.foo # => 'FOO'
#   b2.foo # => 'foo'
#   b1.bar # => 'bar'
#   b2.bar # => 'bar'
#
#
# _Reproxifying_ an object of a _proxified_ class:
#   class C
#     def foo
#       'foo'
#     end
#
#     def bar
#       'bar'
#     end
#   end
#
#   c1, c2 = C.new, C.new
#
#   Proxify(C, :foo, :bar) { super().upcase }
#
#   # the class proxy is overridden
#   Proxify(c1, :foo) { 'proxified' }
#   c1.foo # => 'proxified'
#   c2.foo # => 'FOO'
#   c1.bar # => 'BAR'
#   c2.bar # => 'BAR'
#
#   # if super is called the class' proxy will also be called
#   Proxify(c1, :foo) { "i am a proxified #{super()}"}
#   c1.foo # => 'i am a proxified FOO'
#   c2.foo # => 'FOO'
#   c1.bar # => 'BAR'
#   c2.bar # => 'BAR'
def Proxify(receiver, *methods, &block)
  raise ArgumentError, 'no block given' unless block_given?
  raise ArgumentError, 'no methods given' if methods.empty?

  target = receiver.is_a?(Class) ? receiver : receiver.singleton_class

  target.include(Proxified).proxify(*methods, &block)
end

# If the +receiver+ is _proxified_ unproxifies the given +methods+, or all the
# _proxified_ _methods_ if no +methods+ are given.
#
# +receiver+ can be a class or an ordinary object.
#
# If +receiver+ is an object of a _proxified_ class only its (eventual) proxy
# methods will be removed and the proxy of the class will not be affected.
#
# See Proxified.unproxify for further details.
#
# ======Examples
#
# _Unproxifying_ a _proxified_ class:
#   class A
#     def foo
#       'foo'
#     end
#
#     def bar
#       'bar'
#     end
#
#     def biz
#       'biz'
#     end
#   end
#
#   a1, a2 = A.new, A.new
#
#   Proxify(A, :foo, :bar, :biz) { super().upcase }
#
#   Unproxify(A, :foo)
#   a1.foo # => 'foo'
#   a2.foo # => 'foo'
#   a1.bar # => 'BAR'
#   a2.bar # => 'BAR'
#   a1.biz # => 'BIZ'
#   a2.biz # => 'BIZ'
#
#   Unproxify(A)
#   a1.foo # => 'foo'
#   a2.foo # => 'foo'
#   a1.bar # => 'bar'
#   a2.bar # => 'bar'
#   a1.biz # => 'biz'
#   a2.biz # => 'biz'
#
#
# _Unproxifying_ a _proxified_ object:
#   class B
#     def foo
#       'foo'
#     end
#
#     def bar
#       'bar'
#     end
#
#     def biz
#       'biz'
#     end
#   end
#
#   b1, b2 = B.new, B.new
#
#   Proxify(b1, :foo, :bar, :biz) { super().upcase }
#
#   Unproxify(b1, :foo)
#   b1.foo # => 'foo'
#   b2.foo # => 'foo'
#   b1.bar # => 'BAR'
#   b2.bar # => 'BAR'
#   b1.biz # => 'BIZ'
#   b2.biz # => 'BIZ'
#
#   Unproxify(b1)
#   b1.foo # => 'foo'
#   b2.foo # => 'foo'
#   b1.bar # => 'bar'
#   b2.bar # => 'bar'
#   b1.biz # => 'biz'
#   b2.biz # => 'biz'
#
#
# Trying to _unproxify_ an object of a _proxified_ class:
#   class C
#     def foo
#       'foo'
#     end
#   end
#
#   c1, c2 = C.new, C.new
#
#   Proxify(C, :foo) { super().upcase }
#
#   Unproxify(c1)
#   c1.foo # => 'FOO' (does not work because an object cannot affect its class)
#   c2.foo # => 'FOO'
#
#
# _Unproxifying_ a _reproxified_ object of a _proxified_ class:
#   class D
#     def foo
#       'foo'
#     end
#   end
#
#   d1, d2 = D.new, D.new
#
#   Proxify(D, :foo) { super().upcase }
#
#   Proxify(d1, :foo) { 'proxified'}
#
#   Unproxify(d1)
#   d1.foo # => 'FOO' (the class proxy is restored)
#   d2.foo # => 'FOO'
def Unproxify(receiver, *methods)
  target = receiver.is_a?(Class) ? receiver : receiver.singleton_class

  Proxified?(target) ? target.unproxify(*methods) : methods
end

# If given no +method+, checks whether any of the +receiver+'s instance
# methods is _proxified_, otherwise it checks for the given +method+.
#
# +receiver+ can be a class or an ordinary object.
#
# If +receiver+ is an object of a _proxified_ class and the class has at least a
# _proxified_ method, will return true even when the +receiver+ has no
# _proxified_ methods.
#
# See Proxified.proxified? for further details.
#
# ======Examples
#
# Checking if a class is _proxified_:
#   class A
#     def foo
#       'foo'
#     end
#
#     def bar
#       'bar'
#     end
#   end
#
#   Proxified?(A)       # => false
#   Proxified?(A, :foo) # => false
#   Proxified?(A, :bar) # => false
#
#   Proxify(A, :foo, :bar) { 'proxified' }
#   Proxified?(A)       # => true
#   Proxified?(A, :foo) # => true
#   Proxified?(A, :bar) # => true
#
#   Unproxify(A, :foo)
#   Proxified?(A)       # => true
#   Proxified?(A, :foo) # => false
#   Proxified?(A, :bar) # => true
#
#   Unproxify(A, :bar)
#   Proxified?(A)       # => false
#   Proxified?(A, :foo) # => false
#   Proxified?(A, :bar) # => false
#
#
# Checking if an object is _proxified_:
#   class B
#     def foo
#       'foo'
#     end
#
#     def bar
#       'bar'
#     end
#   end
#
#   b1, b2 = B.new, B.new
#
#   Proxified?(b1)       # => false
#   Proxified?(b1, :foo) # => false
#   Proxified?(b1, :bar) # => false
#   Proxified?(b2)       # => false
#   Proxified?(b2, :foo) # => false
#   Proxified?(b2, :bar) # => false
#
#   Proxify(b1, :foo) { 'proxified' }
#   Proxified?(b1)       # => true
#   Proxified?(b1, :foo) # => true
#   Proxified?(b1, :bar) # => false
#   Proxified?(b2)       # => false
#   Proxified?(b2, :foo) # => false
#   Proxified?(b2, :bar) # => false
#
#   Unproxify(b1)
#   Proxified?(b1)       # => false
#   Proxified?(b1, :foo) # => false
#   Proxified?(b1, :bar) # => false
#   Proxified?(b2)       # => false
#   Proxified?(b2, :foo) # => false
#   Proxified?(b2, :bar) # => false
#
#
# Checking if an object of a _proxified_ class is _proxified_:
#   class C
#     def foo
#       'foo'
#     end
#
#     def bar
#       'bar'
#     end
#   end
#
#   c1, c2 = C.new, C.new
#
#   Proxify(C, :foo) { 'proxified' }
#
#   Proxified?(c1)       # => true
#   Proxified?(c1, :foo) # => true
#   Proxified?(c1, :bar) # => false
#   Proxified?(c2)       # => true
#   Proxified?(c2, :foo) # => true
#   Proxified?(c2, :bar) # => false
#
#   Unproxify(c1)
#   Proxified?(c1)       # => true (the class is not affected)
#   Proxified?(c1, :foo) # => true
#   Proxified?(c1, :bar) # => false
#   Proxified?(c2)       # => true
#   Proxified?(c2, :foo) # => true
#   Proxified?(c2, :bar) # => false
#
#   Unproxify(C)
#   Proxified?(c1)       # => false
#   Proxified?(c1, :foo) # => false
#   Proxified?(c1, :bar) # => false
#   Proxified?(c2)       # => false
#   Proxified?(c2, :foo) # => false
#   Proxified?(c2, :bar) # => false
#
#   Proxify(c1, :foo) { 'proxified' }
#   Unproxify(C)
#   Proxified?(c1)       # => true (is not affected by the class)
#   Proxified?(c1, :foo) # => true
#   Proxified?(c1, :bar) # => false
#   Proxified?(c2)       # => false
#   Proxified?(c2, :foo) # => false
#   Proxified?(c2, :bar) # => false
def Proxified?(receiver, method = nil)
  if receiver.is_a?(Class)
    receiver.include?(Proxified) && receiver.proxified?(method)
  else
    Proxified?(receiver.singleton_class, method) ||
      Proxified?(receiver.class, method)
  end
end

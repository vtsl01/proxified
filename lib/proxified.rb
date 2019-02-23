# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext'

# =====Allows to "proxify" and "unproxify" any instance method with custom code and to inherit and change the behaviour down the class hierarchy.
module Proxified
  extend ::ActiveSupport::Concern

  included do
    # Stores the methods to _proxify_ allowing descendants to override them
    # without affecting the parent.
    class_attribute :proxified_methods, default: {}, instance_accessor: false
  end

  class_methods do
    # For each +method+ in +methods+, defines a _proxified_method_ that
    # runs the given +block+ when +method+ is called, or raises ArgumentError
    # if no +block+ or no +method+ is given.
    #
    # In order not to change the class interface, a method is only _proxified_
    # when the corresponding instance method is defined (before or after the
    # proxy definition), while a _proxified_method_ is removed whenever the
    # corresponding instance method is removed from the class. Moreover, the
    # _proxified_methods_ take the arguments specified by the +block+, so the
    # +block+ should take the same arguments as the original +methods+
    # (although it can take any number of arguments). Finally, it's possible
    # to call the original +methods+ invoking +super+ inside the +block+.
    #
    # The _proxified_methods_ are defined in a proxy module that is prepended
    # automatically to the class only the first time a _proxified_method_ is
    # defined within that class. In this way, descendants who redefine a
    # _proxified_method_ get their own proxy module, while those who do not
    # redefine a _proxified_method_ get the parent's proxy module.
    #
    # Beware: if a child redefines a _proxified_method_ to call _super_, the
    # parent's _proxified_method_ will be called.
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
    #       puts "hello #{name}!"
    #     end
    #
    #     def goodbye(name)
    #       puts "goodbye #{name}!"
    #     end
    #   end
    #
    #   A.ancestors => [A::Proxy, A, Proxified, ...]
    #
    #   a = A.new
    #   a.welcome('jack') => 'checking jack'; 'welcome jack!';
    #   a.goodbye('jack') => 'checking jack'; 'goodbye jack!';
    #   a.welcome => raises ArgumentError
    #   a.check('jack') => 'checking jack' # not proxified
    #
    # Just inheriting:
    #   class B < A; end
    #
    #   B.ancestors => [B, A::Proxy, A, Proxified, ...]
    #
    #   b = B.new
    #   b.welcome('jack') => 'checking jack'; 'welcome jack!';
    #   b.goodbye('jack') => 'checking jack'; 'goodbye jack!';
    #
    # Redefining a +proxified_method+:
    #   class C < A
    #     def welcome(name)
    #       puts "welcome #{name.upcase}!"
    #     end
    #   end
    #
    #   C.ancestors => [C::Proxy, C, A::Proxy, A, Proxified, ...]
    #
    #   c = C.new
    #   c.welcome('jack') => 'checking jack'; 'welcome JACK!';
    #   c.goodbye('jack') => 'checking jack'; 'goodbye jack!';
    #
    # Reproxifing a +proxified_method+:
    #   class D < A
    #     proxify :welcome do |name|
    #       super(name.upcase)
    #     end
    #   end
    #
    #   D.ancestors => [D::Proxy, D, A::Proxy, A, Proxified, ...]
    #
    #   d = D.new
    #   d.welcome('jack') => 'checking JACK'; 'welcome JACK!';
    #   d.goodbye('jack') => 'checking jack'; 'goodbye jack!';
    #
    # Reproxifing and redefining a +proxified_method+:
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
    #   E.ancestors => [E::Proxy, E, A::Proxy, A, Proxified, ...]
    #
    #   e = E.new
    #   e.welcome('jack') => 'hello JACK!';
    #   e.goodbye('jack') => 'checking jack'; 'goodbye jack!';
    #
    # Redefining a +proxified_method+ to call +super+:
    #   class F < A
    #     def welcome(name)
    #       super(name)
    #       puts 'hi'
    #     end
    #   end
    #
    #   F.ancestors => [F::Proxy, F, A::Proxy, A, Proxified, ...]
    #
    #   f = F.new
    #   f.welcome('tom')  => 'checking tom'; 'checking tom'; 'welcome tom!'; 'hi';
    #   f.goodbye('jack') => 'checking jack'; 'goodbye jack!';
    def proxify(*methods, &block)
      raise ArgumentError, 'no block given' unless block_given?
      raise ArgumentError, 'no methods given' if methods.empty?

      methods.each do |method|
        self.proxified_methods = proxified_methods.merge(method => block)
        add_proxy_method(method) if method_defined?(method)
      end
    end

    # Unproxifies the given +methods+ removing them from the proxy. If no
    # +methods+ are given, all the _proxified_methods_ are removed.
    #
    # ======Examples
    #
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
    #   a = A.new
    #   a.welcome('jack') => 'checking jack'; 'welcome jack!';
    #   a.goodbye('jack') => 'checking jack'; 'goodbye jack!';
    #
    #   a.class.unproxify(:welcome)
    #
    #   a.welcome('jack') => 'welcome jack!';
    #   a.goodbye('jack') => 'checking jack'; 'goodbye jack!';
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
    #     proxify :welcome, :goodbye do |name|
    #       super(name.upcase)
    #     end
    #
    #     def welcome(name)
    #       puts "hello #{name}!"
    #     end
    #
    #     def goodbye(name)
    #       puts "goodbye #{name}!"
    #     end
    #   end
    #
    #   A.proxified?           => true
    #   A.proxified?(:welcome) => true
    #   A.proxified?(:goodbye) => true
    #
    #   A.unproxify(:goodbye)
    #
    #   A.proxified?           => true
    #   A.proxified?(:welcome) => true
    #   A.proxified?(:goodbye) => false
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

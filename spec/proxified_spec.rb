# frozen_string_literal: true

RSpec.describe Proxified do
  let(:client) { Class.new { include Proxified } }

  describe '.proxify' do
    before do
      %i[foo bar biz baz].each do |method|
        client.define_method(method) { |name| "#{method}: #{name}" }
      end
    end

    context 'when given no block' do
      it 'raises an ArgumentError' do
        expect { client.proxify(:foo) }.to raise_error(ArgumentError)
      end
    end

    context 'when given no methods' do
      it 'raises an ArgumentError' do
        expect { client.proxify { 'proxified' } }.to raise_error(ArgumentError)
      end
    end

    context 'when the given methods are not proxified' do
      before { client.proxify(:foo, :bar) { |name| super(name + '-proxy') } }

      it 'for each method defines a proxy method that takes the block args' do
        %i[foo bar].each do |method|
          expect { client.new.send(method) }.to raise_error(ArgumentError)
        end
      end

      it 'for each method defines a proxy method that runs the given block' do
        %i[foo bar].each do |method|
          expect(client.new.send(method, 'jack')).to eq("#{method}: jack-proxy")
        end
      end

      it 'does not affect other instance methods' do
        %i[biz baz].each do |method|
          expect(client.new.send(method, 'jack')).to eq("#{method}: jack")
        end
      end
    end

    context 'when the given methods are proxified' do
      before { client.proxify(:foo, :bar) { |name| super(name + '-p1') } }
      before { client.proxify(:foo, :bar) { |name| super(name + '-p2') } }

      it 'redefines the corresponding proxy methods' do
        %i[foo bar].each do |method|
          expect(client.new.send(method, 'jack')).to eq("#{method}: jack-p2")
        end
      end
    end
  end

  describe '.unproxify' do
    before do
      %i[foo bar biz baz].each do |method|
        client.define_method(method) { |name| "#{method}: #{name}" }
      end
    end

    before do
      client.proxify(:foo, :bar, :biz) { |name| super(name + '-proxy') }
    end

    describe 'when given no methods' do
      before { client.unproxify }

      it 'removes all the methods from the proxy' do
        %i[foo bar biz].each do |method|
          expect(client.new.send(method, 'jack')).to eq("#{method}: jack")
        end
      end

      it 'does not affect other instance methods' do
        expect(client.new.baz('jack')).to eq('baz: jack')
      end
    end

    describe 'when given any methods' do
      before { client.unproxify(:foo, :bar) }

      it 'removes the given methods from the proxy' do
        %i[foo bar].each do |method|
          expect(client.new.send(method, 'jack')).to eq("#{method}: jack")
        end
      end

      it 'does not affect other proxy methods' do
        expect(client.new.biz('jack')).to eq('biz: jack-proxy')
      end

      it 'does not affect other instance methods' do
        expect(client.new.baz('jack')).to eq('baz: jack')
      end
    end
  end

  describe '.proxified?' do
    before { client.define_method(:foo) { 'foo' } }

    describe 'when given no method' do
      context 'and no method has been proxified' do
        it { expect(client.proxified?).to be false }
      end

      context 'and at least one method has been proxified' do
        before { client.proxify(:foo) { 'proxified' } }

        it { expect(client.proxified?).to be true }
      end
    end

    describe 'when given a method' do
      context 'and the method has not been proxified' do
        it { expect(client.proxified?(:foo)).to be false }
      end

      context 'and the method has been proxified' do
        before { client.proxify(:foo) { 'proxified' } }

        it { expect(client.proxified?(:foo)).to be true }
      end

      context 'and the method has been proxified and then unproxified' do
        before { client.proxify(:foo) { 'proxified' } }
        before { client.unproxify(:foo) }

        it { expect(client.proxified?(:foo)).to be false }
      end
    end
  end

  describe 'when a method is added to the client' do
    context 'and it has not been proxified' do
      before { client.define_method(:foo) { 'foo' } }

      it 'it is not added to the proxy' do
        expect(client.new.foo).to eq('foo')
      end
    end

    context 'and it has been proxified' do
      before { client.proxify(:foo) { 'proxified' } }

      before { client.define_method(:foo) { 'foo' } }

      it 'it is added to the proxy' do
        expect(client.new.foo).to eq('proxified')
      end
    end
  end

  describe 'when a method is removed from the client' do
    before { client.define_method(:foo) { 'foo' } }

    context 'and it has not been proxified' do
      before { client.remove_method(:foo) }

      it 'nothing happens' do
        expect { client.new.foo }.to raise_error(NoMethodError)
      end
    end

    context 'and it has been proxified' do
      before { client.proxify(:foo) { 'proxified' } }

      before { client.remove_method(:foo) }

      it 'the corresponding method is removed from the proxy' do
        expect { client.new.foo }.to raise_error(NoMethodError)
      end
    end
  end

  describe 'descendants of the client' do
    before do
      %i[foo bar].each do |method|
        client.define_method(method) { |name| "#{method}: #{name}" }
      end
    end

    before { client.proxify(:foo) { |name| super(name + '-ParentProxy') } }

    let(:descendant) { Class.new(client) }

    subject { descendant.new }

    describe 'that proxify a standard method' do
      before { descendant.proxify(:bar) { |name| super(name + '-ChildProxy') } }

      it 'do not proxify the method on the parent' do
        expect(client.new.bar('jack')).to eq('bar: jack')
      end

      it 'run the parent\'s original method within their proxy' do
        expect(descendant.new.bar('jack')).to eq('bar: jack-ChildProxy')
      end
    end

    describe 'that do not reproxify any proxified method' do
      context 'and do not redefine any proxified method' do
        it 'run the parent\'s original method within the parent\'s proxy' do
          expect(subject.foo('jack')).to eq('foo: jack-ParentProxy')
        end
      end

      context 'and redefine a proxified method' do
        before { descendant.define_method(:foo) { |name| "nice foo: #{name}" } }

        it 'run their method within the parent\'s proxy' do
          expect(subject.foo('jack')).to eq('nice foo: jack-ParentProxy')
        end
      end
    end

    describe 'that reproxify a proxified method' do
      before { descendant.proxify(:foo) { |name| super(name + '-ChildProxy') } }

      context 'and do not redefine the reproxified method' do
        it 'run the parent\'s proxy method within their proxy' do
          expect(subject.foo('jack')).to eq('foo: jack-ChildProxy-ParentProxy')
        end
      end

      context 'and redefine the reproxified method' do
        before { descendant.define_method(:foo) { |name| "nice foo: #{name}" } }

        it 'run their method within their proxy' do
          expect(subject.foo('jack')).to eq('nice foo: jack-ChildProxy')
        end
      end
    end
  end
end

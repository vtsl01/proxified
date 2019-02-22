# frozen_string_literal: true

RSpec.describe Proxified do
  let(:client) { Class.new { include Proxified } }

  describe '.proxify' do
    before do
      %i[foo bar biz baz].each do |method|
        client.define_method(method) { |name| "#{method} #{name}" }
      end
    end

    subject { client.new }

    context 'when given no block' do
      it 'raises an ArgumentError' do
        expect { client.proxify(:foo) }.to raise_error(ArgumentError)
      end
    end

    context 'when given no methods' do
      it 'raises an ArgumentError' do
        expect { client.proxify { 'hi' } }.to raise_error(ArgumentError)
      end
    end

    context 'when given some methods and a block' do
      before { client.proxify(:foo, :bar) { |name| super(name.upcase) } }

      it 'defines a proxy method that takes the block args for each method' do
        %i[foo bar].each do |method|
          expect { subject.send(method) }.to raise_error(ArgumentError)
        end
      end

      it 'defines a proxy method that runs the given block for each method' do
        %i[foo bar].each do |method|
          expect(subject.send(method, 'jack')).to eq("#{method} JACK")
        end
      end

      it 'does not define a proxy method for other instance methods' do
        %i[biz baz].each do |method|
          expect(subject.send(method, 'jack')).to eq("#{method} jack")
        end
      end
    end

    context 'when called more than once with the same methods' do
      before { client.proxify(:foo, :bar) { |name| super(name.upcase) } }
      before { client.proxify(:foo, :bar) { |name| super(name.upcase + '!') } }

      it 'redefines the proxy methods' do
        %i[foo bar].each do |method|
          expect(subject.send(method, 'jack')).to eq("#{method} JACK!")
        end
      end
    end
  end

  describe '.unproxify' do
    before do
      %i[foo bar biz baz].each do |method|
        client.define_method(method) { |name| "#{method} #{name}" }
      end
    end

    before { client.proxify(:foo, :bar, :biz) { |name| super(name.upcase) } }

    before { client.unproxify(:foo, :bar) }

    subject { client.new }

    it 'removes the given methods from the proxy' do
      %i[foo bar].each do |method|
        expect(subject.send(method, 'jack')).to eq("#{method} jack")
      end
    end

    it 'does not remove other proxy methods' do
      expect(subject.biz('jack')).to eq('biz JACK')
    end

    it 'does not remove other instance methods' do
      expect(subject.baz('jack')).to eq('baz jack')
    end
  end

  describe '.proxified?' do
    before { client.define_method(:foo) { 'foo' } }

    context 'when the method has not been proxified' do
      it { expect(client.proxified?(:foo)).to be false }
    end

    context 'when the method has been proxified' do
      before { client.proxify(:foo) { super.upcase } }

      it { expect(client.proxified?(:foo)).to be true }
    end

    context 'when the method has been proxified and then unproxified' do
      before { client.proxify(:foo) { super.upcase } }
      before { client.unproxify(:foo) }

      it { expect(client.proxified?(:foo)).to be false }
    end
  end

  describe 'when a method is added to the client' do
    subject { client.new }

    context 'and it has not been proxified' do
      before { client.define_method(:foo) { 'foo' } }

      it 'is not defined as a proxy method' do
        expect(subject.foo).to eq('foo')
      end
    end

    context 'and it has been proxified' do
      before { client.proxify(:foo) { 'bar' } }

      before { client.define_method(:foo) { 'foo' } }

      it 'is defined as a proxy method' do
        expect(subject.foo).to eq('bar')
      end
    end
  end

  describe 'when a method is removed from the client' do
    before { client.proxify(:foo) { 'bar' } }

    before { client.define_method(:foo) { 'foo' } }

    before { client.remove_method(:foo) }

    subject { client.new }

    it 'the corresponding method is removed from the proxy' do
      expect { subject.foo }.to raise_error(NoMethodError)
    end
  end

  describe 'descendants of the client' do
    let(:descendant) { Class.new(client) }

    before { client.proxify(:welcome) { |name| super(name.upcase) } }

    before { client.define_method(:welcome) { |name| "welcome #{name}!" } }

    describe 'inherit proxified methods' do
      it { expect(descendant.proxified?(:welcome)).to be true }
    end

    describe 'can override proxified methods without affecting the parent' do
      before { descendant.unproxify(:welcome) }

      it { expect(descendant.proxified?(:welcome)).to be false }
      it { expect(client.proxified?(:welcome)).to be true }
    end

    describe 'who do not reproxify any method' do
      subject { descendant.new }

      context 'and do not redefine any proxified method' do
        it 'run the parent\'s method within the parent\'s proxy' do
          expect(subject.welcome('jack')).to eq('welcome JACK!')
        end
      end

      context 'and redefine a proxified method' do
        before { descendant.define_method(:welcome) { |name| "hi #{name}!" } }

        it 'run their method within the parent\'s proxy' do
          expect(subject.welcome('jack')).to eq('hi JACK!')
        end
      end
    end

    describe 'who reproxify a method' do
      before { descendant.proxify(:welcome) { |name| super(name).upcase } }

      subject { descendant.new }

      context 'and do not redefine the reproxified method' do
        it 'run the parent\'s method within their proxy' do
          expect(subject.welcome('jack')).to eq('WELCOME JACK!')
        end
      end

      context 'and redefine the reproxified method' do
        before { descendant.define_method(:welcome) { |name| "hi #{name}!" } }

        it 'run their method within their proxy' do
          expect(subject.welcome('jack')).to eq('HI JACK!')
        end
      end
    end
  end
end

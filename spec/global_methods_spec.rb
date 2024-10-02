# frozen_string_literal: true

RSpec.describe 'Proxify()' do
  describe 'when given no block' do
    it 'raises an ArgumentError' do
      expect { Proxify(Object, :to_s) }.to raise_error(ArgumentError)
    end

    it 'does not inject Proxified in the receiver' do
      Proxify(Object, :to_s)
    rescue ArgumentError
      expect(Object.include?(Proxified)).to be false
    end
  end

  describe 'when given no methods' do
    it 'raises an ArgumentError' do
      expect { Proxify(Object) { 'proxified' } }.to raise_error(ArgumentError)
    end

    it 'does not inject Proxified in the receiver' do
      Proxify(Object) { 'proxified' }
    rescue ArgumentError
      expect(Object.include?(Proxified)).to be false
    end
  end

  describe 'when the receiver is a class' do
    let(:receiver) { Class.new }

    before do
      %i[foo bar biz baz].each do |method|
        receiver.define_method(method) { |name| "#{method}: #{name}" }
      end
    end

    subject { receiver.new }

    context 'and the given methods are not proxified' do
      before { Proxify(receiver, :foo, :bar) { |name| super("#{name}-proxy") } }

      it 'injects Proxified in the receiver' do
        expect(receiver.include?(Proxified)).to be true
      end

      it 'proxifies the given methods' do
        %i[foo bar].each do |method|
          expect(subject.send(method, 'jack')).to eq("#{method}: jack-proxy")
        end
      end

      it 'does not affect other instance methods' do
        %i[biz baz].each do |method|
          expect(subject.send(method, 'jack')).to eq("#{method}: jack")
        end
      end
    end

    context 'and the given methods are proxified' do
      before { Proxify(receiver, :foo, :bar) { |name| super("#{name}-p1") } }
      before { Proxify(receiver, :foo, :bar) { |name| super("#{name}-p2") } }

      it 'redefines the corresponding proxy methods' do
        %i[foo bar].each do |method|
          expect(subject.send(method, 'jack')).to eq("#{method}: jack-p2")
        end
      end
    end
  end

  describe 'when the receiver is an object' do
    let(:receiver_class) { Class.new }
    let(:receiver) { receiver_class.new }
    let(:another_object) { receiver_class.new }

    before do
      %i[foo bar biz baz].each do |method|
        receiver_class.define_method(method) { |name| "#{method}: #{name}" }
      end
    end

    describe 'of a standard class' do
      context 'and the given methods are not proxified' do
        before { Proxify(receiver, :foo, :bar) { |name| super("#{name}-prx") } }

        it 'injects Proxified in the receiver\'s singleton class' do
          expect(receiver.singleton_class.include?(Proxified)).to be true
        end

        it 'does not inject Proxified in the receiver\'s class' do
          expect(receiver.class.include?(Proxified)).to be false
        end

        it 'proxifies the given methods on the receiver' do
          %i[foo bar].each do |method|
            expect(receiver.send(method, 'jack')).to eq("#{method}: jack-prx")
          end
        end

        it 'does not proxify the given methods on the receiver\'s class' do
          %i[foo bar].each do |method|
            expect(another_object.send(method, 'jack')).to eq("#{method}: jack")
          end
        end

        it 'does not affect other methods on the receiver' do
          %i[biz baz].each do |method|
            expect(receiver.send(method, 'jack')).to eq("#{method}: jack")
          end
        end

        it 'does not affect other methods on the receiver\'s class' do
          %i[biz baz].each do |method|
            expect(another_object.send(method, 'jack')).to eq("#{method}: jack")
          end
        end
      end

      context 'and the given methods are proxified' do
        before { Proxify(receiver, :foo, :bar) { |name| super("#{name}-p1") } }
        before { Proxify(receiver, :foo, :bar) { |name| super("#{name}-p2") } }

        it 'reproxifies the given methods on the receiver' do
          %i[foo bar].each do |method|
            expect(receiver.send(method, 'jack')).to eq("#{method}: jack-p2")
          end
        end
      end
    end

    describe 'of a proxified class' do
      context 'and the given methods are not proxified' do
        before { Proxify(receiver_class, :foo) { |name| super("#{name}-p1") } }
        before { Proxify(receiver, :bar, :biz) { |name| super("#{name}-p2") } }

        it 'proxifies the given methods on the receiver' do
          %i[bar biz].each do |method|
            expect(receiver.send(method, 'jack')).to eq("#{method}: jack-p2")
          end
        end

        it 'does not proxify the given methods on the receiver\'s class' do
          %i[bar biz].each do |method|
            expect(another_object.send(method, 'jack')).to eq("#{method}: jack")
          end
        end

        it 'does not affect other proxified methods on the receiver' do
          expect(receiver.foo('jack')).to eq('foo: jack-p1')
        end

        it 'does not affect the proxified methods on the receiver\'s class' do
          expect(another_object.foo('jack')).to eq('foo: jack-p1')
        end

        it 'does not affect other methods on the receiver' do
          expect(receiver.baz('jack')).to eq('baz: jack')
        end

        it 'does not affect other methods on the receiver\'s class' do
          expect(another_object.baz('jack')).to eq('baz: jack')
        end
      end

      context 'and the given methods are proxified on the receiver\'s class' do
        before do
          Proxify(receiver_class, :foo, :bar, :biz) do |name|
            super("#{name}-p1")
          end
        end

        before { Proxify(receiver, :foo, :bar) { |name| super("#{name}-p2") } }

        it 'reproxifies the given methods on the receiver' do
          %i[foo bar].each do |method|
            expect(receiver.send(method, 'jack')).to eq("#{method}: jack-p2-p1")
          end
        end

        it 'does not reproxify the given methods on the receiver\'s class' do
          %i[foo bar].each do |method|
            expect(another_object.send(method, 'jack')).to eq("#{method}: jack-p1")
          end
        end

        it 'does not affect other proxified methods on the receiver' do
          expect(receiver.biz('jack')).to eq('biz: jack-p1')
        end

        it 'does not affect the proxified methods on the receiver\'s class' do
          expect(another_object.biz('jack')).to eq('biz: jack-p1')
        end

        it 'does not affect other methods on the receiver' do
          expect(receiver.baz('jack')).to eq('baz: jack')
        end

        it 'does not affect other methods on the receiver\'s class' do
          expect(another_object.baz('jack')).to eq('baz: jack')
        end
      end

      context 'and the given methods are proxified on the receiver' do
        before do
          Proxify(receiver_class, :foo) { |name| super("#{name}-p1") }
        end

        before { Proxify(receiver, :bar, :biz) { |name| super("#{name}-p2") } }

        before { Proxify(receiver, :bar, :biz) { |name| super("#{name}-p3") } }

        it 'reproxifies the given methods on the receiver' do
          %i[bar biz].each do |method|
            expect(receiver.send(method, 'jack')).to eq("#{method}: jack-p3")
          end
        end

        it 'does not proxify the given methods on the receiver\'s class' do
          %i[bar biz].each do |method|
            expect(another_object.send(method, 'jack')).to eq("#{method}: jack")
          end
        end

        it 'does not affect other proxified methods on the receiver' do
          expect(receiver.foo('jack')).to eq('foo: jack-p1')
        end

        it 'does not affect the proxified methods on the receiver\'s class' do
          expect(another_object.foo('jack')).to eq('foo: jack-p1')
        end

        it 'does not affect other methods on the receiver' do
          expect(receiver.baz('jack')).to eq('baz: jack')
        end

        it 'does not affect other methods on the receiver\'s class' do
          expect(another_object.baz('jack')).to eq('baz: jack')
        end
      end
    end
  end
end

RSpec.describe 'Unproxify()' do
  describe 'when the receiver is a class' do
    let(:receiver) { Class.new }

    before do
      %i[foo bar biz baz].each do |method|
        receiver.define_method(method) { |name| "#{method}: #{name}" }
      end
    end

    before do
      Proxify(receiver, :foo, :bar, :biz) { |name| super("#{name}-proxy") }
    end

    context 'and is given no method' do
      before { Unproxify(receiver) }

      it 'removes all the methods from the proxy' do
        %i[foo bar biz].each do |method|
          expect(receiver.new.send(method, 'jack')).to eq("#{method}: jack")
        end
      end

      it 'does not affect other instance methods' do
        expect(receiver.new.baz('jack')).to eq('baz: jack')
      end
    end

    context 'and is given any methods' do
      before { Unproxify(receiver, :foo, :bar) }

      it 'removes the given methods from the proxy' do
        %i[foo bar].each do |method|
          expect(receiver.new.send(method, 'jack')).to eq("#{method}: jack")
        end
      end

      it 'does not affect other proxy methods' do
        expect(receiver.new.biz('jack')).to eq('biz: jack-proxy')
      end

      it 'does not affect other instance methods' do
        expect(receiver.new.baz('jack')).to eq('baz: jack')
      end
    end
  end

  describe 'when the receiver is an object' do
    let(:receiver_class) { Class.new }
    let(:receiver) { receiver_class.new }
    let(:another_object) { receiver_class.new }

    before do
      %i[foo bar biz baz].each do |method|
        receiver_class.define_method(method) { |name| "#{method}: #{name}" }
      end
    end

    describe 'of a standard class' do
      before do
        Proxify(receiver, :foo, :bar, :biz) { |name| super("#{name}-proxy") }
      end

      context 'and is given no method' do
        before { Unproxify(receiver) }

        it 'removes all the methods from the receiver\'s proxy' do
          %i[foo bar biz].each do |method|
            expect(receiver.send(method, 'jack')).to eq("#{method}: jack")
          end
        end

        it 'does not affect other methods on the receiver' do
          expect(receiver.baz('jack')).to eq('baz: jack')
        end

        it 'does not affect other methods on the receiver\'s class' do
          %i[foo bar biz baz].each do |method|
            expect(another_object.send(method, 'jack')).to eq("#{method}: jack")
          end
        end
      end

      context 'and is given any methods' do
        before { Unproxify(receiver, :foo, :bar) }

        it 'removes the given methods from the receiver\'s proxy' do
          %i[foo bar].each do |method|
            expect(receiver.send(method, 'jack')).to eq("#{method}: jack")
          end
        end

        it 'does not affect other proxified methods on the receiver' do
          expect(receiver.biz('jack')).to eq('biz: jack-proxy')
        end

        it 'does not affect other methods on the receiver' do
          expect(receiver.baz('jack')).to eq('baz: jack')
        end

        it 'does not affect other methods on the receiver\'s class' do
          %i[foo bar biz baz].each do |method|
            expect(another_object.send(method, 'jack')).to eq("#{method}: jack")
          end
        end
      end
    end

    describe 'of a proxified class' do
      before do
        Proxify(receiver_class, :foo, :bar) { |name| super("#{name}-p1") }
      end

      before do
        Proxify(receiver, :foo, :bar, :biz) { |name| super("#{name}-p2") }
      end

      context 'and is given no method' do
        before { Unproxify(receiver) }

        it 'removes all the methods from the receiver\'s proxy' do
          %i[foo bar].each do |method|
            expect(receiver.send(method, 'jack')).to eq("#{method}: jack-p1")
          end
          expect(receiver.biz('jack')).to eq('biz: jack')
        end

        it 'does not affect other methods on the receiver' do
          expect(receiver.baz('jack')).to eq('baz: jack')
        end

        it 'does not affect the proxified methods on the receiver\'s class' do
          %i[foo bar].each do |method|
            expect(another_object.send(method, 'jack')).to eq("#{method}: jack-p1")
          end
        end

        it 'does not affect other methods on the receiver\'s class' do
          %i[biz baz].each do |method|
            expect(another_object.send(method, 'jack')).to eq("#{method}: jack")
          end
        end
      end

      context 'and is given any methods' do
        before { Unproxify(receiver, :foo, :bar) }

        it 'removes the given methods from the receiver\'s proxy' do
          %i[foo bar].each do |method|
            expect(receiver.send(method, 'jack')).to eq("#{method}: jack-p1")
          end
        end

        it 'does not affect other proxified methods on the receiver' do
          expect(receiver.biz('jack')).to eq('biz: jack-p2')
        end

        it 'does not affect other methods on the receiver' do
          expect(receiver.baz('jack')).to eq('baz: jack')
        end

        it 'does not affect the proxified methods on the receiver\'s class' do
          %i[foo bar].each do |method|
            expect(another_object.send(method, 'jack')).to eq("#{method}: jack-p1")
          end
        end

        it 'does not affect other methods on the receiver\'s class' do
          %i[biz baz].each do |method|
            expect(another_object.send(method, 'jack')).to eq("#{method}: jack")
          end
        end
      end
    end
  end
end

RSpec.describe 'Proxified?()' do
  describe 'when the receiver is a class' do
    let(:receiver) { Class.new }

    before { receiver.define_method(:foo) { 'foo' } }

    describe 'and is given no method' do
      context 'and no method has been proxified' do
        it { expect(Proxified?(receiver)).to be false }
      end

      context 'and at least a method has been proxified' do
        before { Proxify(receiver, :foo) { 'proxified' } }

        it { expect(Proxified?(receiver)).to be true }
      end
    end

    describe 'and is given a method' do
      context 'and the method has not been proxified' do
        it { expect(Proxified?(receiver, :foo)).to be false }
      end

      context 'and the method has been proxified' do
        before { Proxify(receiver, :foo) { 'proxified' } }

        it { expect(Proxified?(receiver, :foo)).to be true }
      end

      context 'and the method has been proxified and then unproxified' do
        before { Proxify(receiver, :foo) { 'proxified' } }
        before { Unproxify(receiver, :foo) }

        it { expect(Proxified?(receiver, :foo)).to be false }
      end
    end
  end

  describe 'when the receiver is an object' do
    let(:receiver_class) { Class.new }
    let(:receiver) { receiver_class.new }

    before { receiver_class.define_method(:foo) { 'foo' } }
    before { receiver_class.define_method(:bar) { 'bar' } }

    describe 'of a standard class' do
      describe 'and is given no method' do
        context 'and no method has been proxified' do
          it { expect(Proxified?(receiver)).to be false }
        end

        context 'and at least a method has been proxified' do
          before { Proxify(receiver, :foo) { 'proxified' } }

          it { expect(Proxified?(receiver)).to be true }
        end
      end

      describe 'and is given a method' do
        context 'and the method has not been proxified' do
          it { expect(Proxified?(receiver, :foo)).to be false }
        end

        context 'and the method has been proxified' do
          before { Proxify(receiver, :foo) { 'proxified' } }

          it { expect(Proxified?(receiver, :foo)).to be true }
        end

        context 'and the method has been proxified and then unproxified' do
          before { Proxify(receiver, :foo) { 'proxified' } }
          before { Unproxify(receiver, :foo) }

          it { expect(Proxified?(receiver, :foo)).to be false }
        end
      end
    end

    describe 'of a proxified class' do
      before { Proxify(receiver_class, :foo) { 'proxified' } }

      describe 'and is given no method' do
        context 'and no method has been proxified on the receiver' do
          it { expect(Proxified?(receiver)).to be true }
        end

        context 'and at least a method has been proxified on the receiver' do
          before { Proxify(receiver, :bar) { 'proxified' } }

          it { expect(Proxified?(receiver)).to be true }
        end
      end

      describe 'and is given a method' do
        context 'and the method has not been proxified' do
          it { expect(Proxified?(receiver, :bar)).to be false }
        end

        context 'and the method has been proxified on the receiver' do
          before { Proxify(receiver, :bar) { 'proxified' } }

          it { expect(Proxified?(receiver, :bar)).to be true }
        end

        context 'and the method has been proxified on the receiver\'s class' do
          it { expect(Proxified?(receiver, :foo)).to be true }
        end

        context 'and the method has been proxified and then unproxified on the receiver' do
          before { Proxify(receiver, :bar) { 'proxified' } }
          before { Unproxify(receiver, :bar) }

          it { expect(Proxified?(receiver, :bar)).to be false }
        end

        context 'and the method has been proxified on the receiver\'s class and then unproxified on the receiver' do
          before { Unproxify(receiver, :foo) }

          it { expect(Proxified?(receiver, :foo)).to be true }
        end

        context 'and the method has been reproxified on the receiver and then unproxified on the receiver\'s class' do
          before { Proxify(receiver, :foo) { 'proxified again' } }
          before { Unproxify(receiver_class, :foo) }

          it { expect(Proxified?(receiver, :foo)).to be true }
        end
      end
    end
  end
end

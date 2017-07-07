require 'spec_helper'

module Pathway
  describe Operation do
    module SimplePlugin
      module InstanceMethods
        def foo; end
      end

      module ClassMethods
        def bar; end
      end

      module DSLMethods
        def qux; end
      end

      def self.apply(klass)
        klass.result_at :the_result
      end
    end

    class AnOperation < Operation
      plugin SimplePlugin
    end

    class ASubOperation < AnOperation
    end

    class OtherOperation < Operation
    end

    describe '.plugin' do
      it 'includes InstanceMethods module to the class and its subclasses' do
        expect(AnOperation.instance_methods).to include(:foo)
        expect(ASubOperation.instance_methods).to include(:foo)
      end

      it 'includes ClassMethods module to the singleton class and its subclasses' do
        expect(AnOperation.methods).to include(:bar)
        expect(ASubOperation.methods).to include(:bar)
      end

      it 'includes DSLMethods module to the nested DSL class and its subclasses' do
        expect(AnOperation::DSL.instance_methods).to include(:qux)
        expect(ASubOperation::DSL.instance_methods).to include(:qux)
      end

      it "calls 'apply' on the Operation where is used" do
        expect(AnOperation.result_key).to eq(:the_result)
      end

      it 'does not affect main Operation class' do
        expect(Operation.instance_methods).to_not include(:foo)
        expect(Operation.methods).to_not include(:bar)
        expect(Operation::DSL.instance_methods).to_not include(:qux)
        expect(Operation.result_key).to eq(:value)
      end

      it 'does not affect other Operation subclasses' do
        expect(OtherOperation.instance_methods).to_not include(:foo)
        expect(OtherOperation.methods).to_not include(:bar)
        expect(OtherOperation::DSL.instance_methods).to_not include(:qux)
        expect(OtherOperation.result_key).to eq(:value)
      end
    end
  end
end

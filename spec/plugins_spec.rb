# frozen_string_literal: true

require "spec_helper"

module Pathway
  describe Operation do
    module SimplePlugin
      module InstanceMethods
        attr :foo
      end

      module ClassMethods
        attr_accessor :bar

        def inherited(subclass)
          super
          subclass.bar = bar
        end
      end

      module DSLMethods
        attr :qux
      end

      def self.apply(opr, bar: nil)
        opr.result_at :the_result
        opr.bar = bar
      end
    end

    class AnOperation < Operation
      plugin SimplePlugin, bar: "SOME VALUE"
    end

    class ASubOperation < AnOperation
    end

    class OtherOperation < Operation
    end

    describe ".plugin" do
      it "includes InstanceMethods module to the class and its subclasses" do
        expect(AnOperation.instance_methods).to include(:foo)
        expect(ASubOperation.instance_methods).to include(:foo)
      end

      it "includes ClassMethods module to the singleton class and its subclasses" do
        expect(AnOperation.methods).to include(:bar)
        expect(ASubOperation.methods).to include(:bar)
      end

      it "includes DSLMethods module to the nested DSL class and its subclasses" do
        expect(AnOperation::DSL.instance_methods).to include(:qux)
        expect(ASubOperation::DSL.instance_methods).to include(:qux)
      end

      it "calls 'apply' with its arguments on the Operation where is used" do
        expect(AnOperation.result_key).to eq(:the_result)
        expect(AnOperation.bar).to eq("SOME VALUE")
        expect(ASubOperation.bar).to eq("SOME VALUE")
      end

      it "does not affect main Operation class" do
        expect(Operation.instance_methods).to_not include(:foo)
        expect(Operation.methods).to_not include(:bar)
        expect(Operation::DSL.instance_methods).to_not include(:qux)
        expect(Operation.result_key).to eq(:value)
      end

      it "does not affect other Operation subclasses" do
        expect(OtherOperation.instance_methods).to_not include(:foo)
        expect(OtherOperation.methods).to_not include(:bar)
        expect(OtherOperation::DSL.instance_methods).to_not include(:qux)
        expect(OtherOperation.result_key).to eq(:value)
      end
    end
  end
end

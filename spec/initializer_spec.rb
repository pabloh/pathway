require 'spec_helper'

module Pathway
  describe Initializer do
    let(:repository) { double }

    describe ".[]" do
      let(:result) { Initializer[:foobar] }
      it "returns a module" do
        expect(result).to be_a(Module)
      end

      context "when including the resulting module" do
        let(:operation_class) { Class.new(Operation) { include Initializer[:foo, :bar, quz: "QUZ"] } }
        let(:operation) { operation_class.new(foo: "FOO", bar: "BAR", quz: "CORGE", qux: "QUX") }

        it "defines 'initialize' method" do
          expect(operation.foo).to eq("FOO")
          expect(operation.bar).to eq("BAR")
          expect(operation.quz).to eq("CORGE")
        end

        it "defines a 'context' method with the passed values" do
          expect(operation.context).to eq(foo: "FOO", bar: "BAR", quz: "CORGE")
          expect(operation.context).to be_frozen
        end

        it "defines instance method accessors for each param" do
          operation.foo = "XXX"
          operation.bar = "ZZZ"
          operation.quz = "YYY"

          expect(operation.foo).to eq("XXX")
          expect(operation.bar).to eq("ZZZ")
          expect(operation.quz).to eq("YYY")
        end

        context "and initializing without a non default value" do
          it "raise an error" do
            expect { operation_class.new(foo: "FOO") }.to raise_error.
              with_message(":bar was not found in scope")
          end
        end

        context "and initializing without a default value" do
          let(:operation) { operation_class.new(foo: "FOO", bar: "BAR") }

          it "sets correct values" do
            expect(operation.foo).to eq("FOO")
            expect(operation.bar).to eq("BAR")
            expect(operation.quz).to eq("QUZ")
          end
        end

        context "and initializing using false as value" do
          let(:operation) { operation_class.new(foo: false, bar: "BAR") }

          it "sets correct values" do
            expect(operation.foo).to eq(false)
            expect(operation.bar).to eq("BAR")
            expect(operation.quz).to eq("QUZ")
          end
        end
      end

    end
  end
end

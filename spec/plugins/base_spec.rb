# frozen_string_literal: true

require 'spec_helper'

module Pathway
  module Plugins
    describe Base do

      class OperationWithSteps < Operation
        context :validator, :back_end, :notifier, :cond
        result_at :result_value

        process do
          step :custom_validate
          set  :get_value
          set  :get_aux_value, to: :aux_value
          around(-> seq, st { seq.call if cond.call(st) }) do
            set ->_ { 99 }, to: :aux_value
            set ->_ { :UPDATED }
          end
          around(:if_zero) do
            set ->_ { :ZERO }
          end
          if_true(:negative?) do
            set ->_ { :NEGATIVE }
          end
          if_false(:small?) do
            set ->_ { :BIG }
          end
          step :notify
        end

        def custom_validate(state)
          state[:params] = @validator.call(state)
        end

        def get_value(params:, **)
          @back_end.call(params)
        end

        def get_aux_value(state)
          state[result_key]
        end

        def if_zero(seq, state)
          seq.call if state[:result_value] == 0
        end

        def negative?(state)
          state[:result_value].is_a?(Numeric) && state[:result_value].negative?
        end

        def small?(state)
          !state[:result_value].is_a?(Numeric) || state[:result_value].abs < 1_000_000
        end

        def notify(state)
          @notifier.call(state)
        end
      end

      let(:validator) { double }
      let(:back_end)  { double }
      let(:notifier)  { double }
      let(:cond)      { double }

      let(:ctx) { { validator: validator, back_end: back_end, notifier: notifier, cond: cond } }
      subject(:operation) { OperationWithSteps.new(ctx) }

      before do
        allow(validator).to receive(:call) do |input:, **|
          input.key?(:foo) ? input : Result.failure(:validation)
        end

        allow(back_end).to receive(:call).and_return(123456)
        allow(cond).to receive(:call).and_return(false)

        allow(notifier).to receive(:call)
      end

      let(:input) { { foo: 'FOO' } }
      let(:result) { operation.call(input) }

      describe ".process" do
        it "defines a 'call' method wich saves operation argument into the :input key" do
          expect(validator).to receive(:call) do |state|
            expect(state).to respond_to(:to_hash)
            expect(state.to_hash).to include(input: :my_input_test_value)

            Result.failure(:validation)
          end

          operation.call(:my_input_test_value)
        end

        it "defines a 'call' method which returns a value using the key specified by 'result_at'" do
          expect(back_end).to receive(:call).and_return(:SOME_RETURN_VALUE)

          expect(result).to be_a_success
          expect(result.value).to eq(:SOME_RETURN_VALUE)
        end
      end

      describe ".call" do
        let(:result) { OperationWithSteps.call(ctx, input) }
        it "creates a new instance an invokes the 'call' method on it" do
          expect(back_end).to receive(:call).and_return(:SOME_RETURN_VALUE)

          expect(result).to be_a_success
          expect(result.value).to eq(:SOME_RETURN_VALUE)
        end
      end

      describe "#set" do
        it "defines an updating step which sets the result key if no key is specified" do
          expect(back_end).to receive(:call).and_return(:SOME_VALUE)

          expect(notifier).to receive(:call) do |state|
            expect(state).to respond_to(:to_hash)
            expect(state.to_hash).to include(result_value: :SOME_VALUE)
          end

          operation.call(input)
        end

        it "defines an updating step which sets the specified key" do
          expect(back_end).to receive(:call) do |state|
            expect(state).to respond_to(:to_hash).and exclude(:aux_value)

            :RETURN_VALUE
          end

          expect(notifier).to receive(:call) do |state|
            expect(state.to_hash).to include(aux_value: :RETURN_VALUE)
          end

          operation.call(input)
        end
      end

      describe "#step" do
        it "defines an non updating step" do
          expect(notifier).to receive(:call) { { result_value: 0 } }

          expect(result.value).to eq(123456)
        end
      end

      describe "#around" do
        it "provides the steps and state as the block parameter" do
          expect(cond).to receive(:call) do |state|
            expect(state.to_hash).to include(result_value: 123456, aux_value: 123456)

            true
          end

          expect(result.value).to eq(:UPDATED)
        end

        it "transfers inner steps' state to the outer steps" do
          expect(cond).to receive(:call).and_return(true)

          expect(notifier).to receive(:call) do |state|
            expect(state.to_hash).to include(aux_value: 99, result_value: :UPDATED)
          end

          expect(result.value).to eq(:UPDATED)
        end

        it "is skiped altogether on a failure state" do
          allow(back_end).to receive(:call).and_return(Result.failure(:not_available))
          expect(cond).to_not receive(:call)

          expect(result).to be_a_failure
        end

        it "accepts a method name as a parameter" do
          allow(back_end).to receive(:call).and_return(0)

          expect(result.value).to eq(:ZERO)
        end
      end

      describe "#if_true" do
        before { allow(back_end).to receive(:call).and_return(77) }

        it "runs the inner steps when the condition is meet" do
          allow(back_end).to receive(:call).and_return(-77)
          expect(result.value).to eq(:NEGATIVE)
        end

        it "skips the inner steps when the condition is not meet" do
          expect(result.value).to eq(77)
        end
      end

      describe "#if_false" do
        before { allow(back_end).to receive(:call).and_return(77) }

        it "runs the inner steps when the condition not is meet" do
          allow(back_end).to receive(:call).and_return(77_000_000)
          expect(result.value).to eq(:BIG)
        end

        it "skips the inner steps when the condition is meet" do
          expect(result.value).to eq(77)
        end
      end

    end
  end
end

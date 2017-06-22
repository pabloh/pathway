require 'spec_helper'

module Pathway
  module Plugins
    module Flow

      describe DSL do
        class OperationWithSteps < Operation
          scope :validator, :back_end, :notifier, :cond
          result_at :result_value

          process do
            step :_custom_validate
            set  :_get_value
            set  :aux_value, :_get_aux_value
            sequence(-> seq, st { seq.call if cond.call(st) }) do
              set :aux_value, ->_ { 99 }
              set ->_ { :UPDATED }
            end
            sequence(:if_zero) do
              set ->_ { :ZERO }
            end
            step :_notify
          end

          private

          def _custom_validate(state)
            state[:params] = @validator.call(state)
          end

          def _get_value(params:, **)
            @back_end.call(params)
          end

          def _get_aux_value(state)
            state[result_key]
          end

          def if_zero(seq, state)
            seq.call if state[:result_value] == 0
          end

          def _notify(state)
            @notifier.call(state)
          end
        end

        let(:validator) { double }
        let(:back_end)  { double }
        let(:notifier)  { double }
        let(:cond)      { double }

        subject(:operation) do
          OperationWithSteps.new(validator: validator, back_end: back_end, notifier: notifier, cond: cond)
        end

        before do
          allow(validator).to receive(:call) do |input:, **|
            input.key?(:foo) ? input : Result.failure(:validation)
          end

          allow(back_end).to receive(:call).and_return(1234567890)
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

        describe "#sequence" do
          it "provides the step sequence and state as the block parameter" do
            expect(cond).to receive(:call) do |state|
              expect(state.to_hash).to include(result_value: 1234567890, aux_value: 1234567890)

              true
            end

            expect(result.value).to eq(:UPDATED)
          end

          it "transfers inner sequence state to the outer sequence" do
            expect(cond).to receive(:call).and_return(true)

            expect(notifier).to receive(:call) do |state|
              expect(state.to_hash).to include(aux_value: 99, result_value: :UPDATED)
            end

            expect(result.value).to eq(:UPDATED)
          end

          it "is skiped althougher on a failure state" do
            allow(back_end).to receive(:call).and_return(Result.failure(:not_available))
            expect(cond).to_not receive(:call)

            expect(result).to be_a_failure
          end

          it "accepts a method name as a parameter" do
            allow(back_end).to receive(:call).and_return(0)

            expect(result.value).to eq(:ZERO)
          end
        end

        describe "#step" do
          it "defines an non updating step" do
            expect(notifier).to receive(:call) { { result_value: 0 } }

            expect(result.value).to eq(1234567890)
          end
        end
      end

    end
  end
end

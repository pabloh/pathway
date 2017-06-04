require 'spec_helper'

module Pathway
  class Operation
    describe Flow do
      class OperationWithSteps < Operation
        scope :validator, :back_end, :notifier, :mailer
        result_at :result_value

        process do
          step :_custom_validate
          set  :_get_value
          set  :aux_value { |state| state[:result_value] }
          step :_notify
          step { |result_value:, **| _send_emails(result_value) }
        end

        private

        def _custom_validate(state)
          state[:params] = @validator.call(state)
        end

        def _get_value(params:, **)
          @back_end.call(params)
        end

        def _notify(state)
          @notifier.call(state)
        end

        def _send_emails(value)
          @mailer.call(value)
        end
      end

      describe '.process' do
        let(:validator) { double }
        let(:back_end)  { double }
        let(:notifier)  { double }
        let(:mailer)    { double }

        subject(:operation) do
          OperationWithSteps.new(validator: validator, back_end: back_end, notifier: notifier, mailer: mailer)
        end

        before do
          allow(validator).to receive(:call) do |input:, **|
            input.key?(:foo) ? input : Result.failure(:validation)
          end

          allow(back_end).to receive(:call).and_return(1234567890)

          allow(notifier).to receive(:call)
          allow(mailer).to receive(:call)
        end

        let(:input) { { foo: 'FOO' } }
        let(:result) { operation.call(input) }

        it 'defines a call method wich saves operation argument into the :input key' do
          expect(validator).to receive(:call) do |state|
            expect(state).to respond_to(:to_hash)
            expect(state.to_hash).to include(input: :my_input_test_value)

            Result.failure(:validation)
          end

          operation.call(:my_input_test_value)
        end

        it "defines an updating step which sets the result key when using 'set' with no key" do
          expect(back_end).to receive(:call).and_return(:SOME_VALUE)

          expect(notifier).to receive(:call) do |state|
            expect(state).to respond_to(:to_hash)
            expect(state.to_hash).to include(result_value: :SOME_VALUE)
          end

          operation.call(input)
        end

        it "defines an updating step when using 'set' with a block" do
          expect(back_end).to receive(:call) do |state|
            expect(state).to respond_to(:to_hash).and exclude(:aux_value)

            :RETURN_VALUE
          end

          expect(notifier).to receive(:call) do |state|
            expect(state.to_hash).to include(aux_value: :RETURN_VALUE)
          end

          operation.call(input)
        end

        it "defines an non updating step when using 'step'" do
          expect(notifier).to receive(:call) { { result_value: 0 } }
          expect(mailer).to receive(:call) { { result_value: 0 } }

          expect(result.value).to eq(1234567890)
        end

        it "defines a return value using the key specified by 'result_at'" do
          expect(back_end).to receive(:call).and_return(:SOME_RETURN_VALUE)

          expect(result).to be_a_success
          expect(result.value).to eq(:SOME_RETURN_VALUE)
        end
      end

    end
  end
end

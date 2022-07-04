# frozen_string_literal: true

require 'spec_helper'

module Pathway
  describe State do
    class SimpleOp < Operation
      context :foo, bar: 10
      result_at :the_result
    end

    let(:operation) { SimpleOp.new(foo: 20) }
    let(:values)    { { input: 'some value' } }
    subject(:state) { State.new(operation, values) }

    describe 'pattern matching' do
      context 'internal values' do
        let(:result) do
          case state
          in input:
            input
          end
        end

        it 'can extract values from internal state' do
          expect(result).to eq('some value')
        end
      end

      context 'operation context values' do
        let(:result) do
          case state
          in foo:, bar: 10
            foo
          end
        end

        it 'can extract values from operation context' do
          expect(result).to eq(20)
        end
      end
    end
  end
end

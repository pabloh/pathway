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

    describe '#initialize' do
      it 'initialize its variables from the operation context and values argument' do
        expect(state.to_hash).to eq(foo: 20, bar: 10, input: 'some value')
      end
    end

    describe '#to_hash' do
      let(:result) { state.update(foobar: 25).to_hash }
      it 'returns a hash with its internal values' do
        expect(result).to be_a(Hash)
          .and eq(foo: 20, bar: 10, input: 'some value', foobar: 25)
      end
    end

    describe '#update' do
      let(:result) { state.update(qux: 33, quz: 11) }
      it 'returns and updated state with the passed values' do
        expect(result.to_hash).to include(qux: 33, quz: 11)
      end
    end

    describe '#result' do
      let(:result) { state.update(the_result: 99).result }
      it 'returns the value corresponding to the result key' do
        expect(result).to eq(99)
      end
    end
  end
end

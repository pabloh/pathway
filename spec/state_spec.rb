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

    describe '#use' do
      before { state.update(val: 'RESULT', foo: 99, bar: 131) }
      it 'fails if no block is provided' do
        expect { state.use }.to raise_error('a block must be provided')
      end

      context 'when a block is provided' do
        it 'passes specified values using only keyword params', :aggregate_failures do
          expect(state.use {|val:| val }).to eq('RESULT')
          expect(state.use {|foo:| foo }).to eq(99)
          expect(state.use {|val:, bar:| [val, bar] })
            .to eq(['RESULT', 131])
        end

        it 'passes no arguments if no keyword or positional params are defined' do
          expect(state.use { 77 }).to eq(77)
        end

        it 'passes specified values using only positional params', :aggregate_failures do
          expect(state.use {|val| val }).to eq('RESULT')
          expect(state.use {|foo| foo }).to eq(99)
          expect(state.use {|val, bar| [val, bar] })
        end

        it 'fails if positional and keyword params are both defined', :aggregate_failures do
          expect { state.use {|pos, input:| } }
            .to raise_error('cannot mix positional and keyword arguments')
        end

        it 'fails if using rest param', :aggregate_failures do
          expect { state.use {|*input| } }
            .to raise_error('rest arguments are not supported')
          expect { state.use {|input, *args| args } }
            .to raise_error('rest arguments are not supported')
        end

        it 'fails if using keyrest param', :aggregate_failures do
          expect { state.use {|**kargs| kargs } }
            .to raise_error('rest arguments are not supported')
          expect { state.use {|input:, **kargs| kargs } }
            .to raise_error('rest arguments are not supported')
        end

        context 'that takes a block argument' do
          it 'fails if it has positional and keyword params' do
            expect { state.use {|input, val:, &bl| } }
              .to raise_error('cannot mix positional and keyword arguments')
          end

          it 'does not fails if only has keyword params', :aggregate_failures do
            expect(state.use {|val:, &bl| val }).to eq('RESULT')
            expect(state.use {|val:, &_| val }).to eq('RESULT')
            expect(state.use {|&_| 77 }).to eq(77)
          end

          it 'does not fails if only has positional params', :aggregate_failures do
            expect(state.use {|val, &bl| val }).to eq('RESULT')
            expect(state.use {|val, &_| val }).to eq('RESULT')
          end
        end

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

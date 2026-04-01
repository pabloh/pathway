# frozen_string_literal: true

require "spec_helper"

RSpec.describe Pathway::State do
  before do
    stub_const("SimpleOp", Class.new(Pathway::Operation) do
      context :foo, bar: 10
      result_at :the_result
    end)
  end

  let(:operation) { SimpleOp.new(foo: 20) }
  let(:values)    { { input: "some value" } }
  subject(:state) { described_class.new(operation, values) }

  describe "pattern matching" do
    context "internal values" do
      let(:result) do
        case state
        in input:
          input
        end
      end

      it "can extract values from internal state" do
        expect(result).to eq("some value")
      end
    end

    context "operation context values" do
      let(:result) do
        case state
        in foo:, bar: 10
          foo
        end
      end

      it "can extract values from operation context" do
        expect(result).to eq(20)
      end
    end
  end
end

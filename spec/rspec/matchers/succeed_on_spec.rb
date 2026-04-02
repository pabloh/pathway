# frozen_string_literal: true

require "spec_helper"

RSpec.describe ":succeed_on matcher" do
  before do
    stub_const("SpecOperation", Class.new(Pathway::Operation) do
      context :valid

      def call(_)
        if @valid
          Pathway::Result.success("PEPE")
        else
          Pathway::Result.failure(Pathway::Error.new(type: :forbidden))
        end
      end
    end)
  end

  let(:input) { double("input") }
  let(:success_operation) { SpecOperation.new(valid: true) }
  let(:failure_operation) { SpecOperation.new(valid: false) }

  context "when used inside an expectation" do
    context "and with a successful operation" do
      it "matches" do
        expect(success_operation).to succeed_on(input)
      end

      it "matches chained 'returning' expected result" do
        expect(success_operation).to succeed_on(input).returning("PEPE")
      end

      it "supports composable matchers for result" do
        expect(success_operation).to succeed_on(input).returning(a_string_starting_with("PEP"))
      end

      it "fails with a diff-friendly message when the return value doesn't match" do
        expect do
          expect(success_operation).to succeed_on(input).returning("OTHER")
        end.to fail_with('Expected successful operation to return "OTHER" but instead got "PEPE"')
      end
    end

    context "and with a failed operation" do
      it "fails with a type-aware message" do
        expect do
          expect(failure_operation).to succeed_on(input)
        end.to fail_with("Expected operation to be successful but failed with :forbidden error")
      end
    end
  end

  context "when used inside a negated expectation" do
    it "matches if operation is failed" do
      expect(failure_operation).not_to succeed_on(input)
    end

    it "fails with a custom message if operation is successful" do
      expect do
        expect(success_operation).not_to succeed_on(input)
      end.to fail_with("Did not to expected operation to be successful but it was")
    end

    it "raises an error when combining with :returning chain" do
      dummy = double("Never called")

      expect do
        expect(dummy).not_to succeed_on(input).returning("PEPE")
      end.to raise_error(
        NotImplementedError,
        "`expect().not_to succeed_on(input).returning()` is not supported."
      )
    end
  end
end

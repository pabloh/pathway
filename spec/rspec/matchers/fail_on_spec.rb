# frozen_string_literal: true

require "spec_helper"

RSpec.describe ":fail_on matcher" do
  before do
    stub_const("SpecOperation", Class.new(Pathway::Operation) do
      context :valid

      def call(_)
        if @valid
          Pathway::Result.success("PEPE")
        else
          error = Pathway::Error.new(type: :forbidden, message: "Nope", details: { name: ["is missing"] })
          Pathway::Result.failure(error)
        end
      end
    end)
  end

  let(:input) { double("input") }
  let(:failure_operation) { SpecOperation.new(valid: false) }
  let(:success_operation) { SpecOperation.new(valid: true) }

  context "when used inside an expectation" do
    context "and with a failed operation" do
      it "matches" do
        expect(failure_operation).to fail_on(input)
      end

      it "matches with expected type" do
        expect(failure_operation).to fail_on(input).with_type(:forbidden)
      end

      it "matches with expected message" do
        expect(failure_operation).to fail_on(input).with_message("Nope")
      end

      it "matches with expected details" do
        expect(failure_operation).to fail_on(input).with_details(name: ["is missing"])
      end

      it "supports composable matchers for chained fields" do
        expect(failure_operation).to fail_on(input).with_message(a_string_starting_with("No"))
      end

      it "supports chaining type, message and details" do
        expect(failure_operation).to fail_on(input)
                                       .with_type(:forbidden)
                                       .and_message("Nope")
                                       .and_details(name: ["is missing"])
      end

      it "fails with a mismatch error for unexpected error type" do
        expect do
          expect(failure_operation).to fail_on(input).with_type(:validation)
        end.to fail_with("Expected failed operation to have type :validation but instead was :forbidden")
      end

      it "fails with a mismatch error for unexpected error message" do
        expect do
          expect(failure_operation).to fail_on(input).with_message("Invalid")
        end.to fail_with('Expected failed operation to have message like "Invalid" but instead got "Nope"')
      end

      it "fails with a mismatch error for unexpected details" do
        expect do
          expect(failure_operation).to fail_on(input).with_details(name: ["is too short"])
        end.to fail_with('Expected failed operation to have details like {name: ["is too short"]} but instead got {name: ["is missing"]}')
      end

      it "fails with a detailed mismatch error when two fields are mismatched" do
        expect do
          expect(failure_operation).to fail_on(input)
                                         .with_type(:validation)
                                         .and_message("Invalid")
                                         .and_details(name: ["is missing"])
        end.to fail_with("Expected failed operation to have type :validation but instead was :forbidden; " \
                         'and have message like "Invalid" but instead got "Nope"')
      end

      it "fails with a detailed mismatch error when all fields are mismatched" do
        expect do
          expect(failure_operation).to fail_on(input)
                                         .with_type(:validation)
                                         .and_message("Invalid")
                                         .and_details(name: ["is too short"])
        end.to fail_with("Expected failed operation to have type :validation but instead was :forbidden; " \
                         'have message like "Invalid" but instead got "Nope"; ' \
                         'and have details like {name: ["is too short"]} but instead got {name: ["is missing"]}')
      end
    end

    context "and with a successful operation" do
      it "fails when the operation succeeds" do
        expect do
          expect(success_operation).to fail_on(input)
        end.to fail_with("Expected operation to fail but it didn't")
      end
    end
  end

  context "when used inside a negated expectation" do
    it "matches if operation is successful" do
      expect(success_operation).not_to fail_on(input)
    end

    context "and with a failed operation" do
      it "fails with custom failure message" do
        expect do
          expect(failure_operation).not_to fail_on(input)
        end.to fail_with("Did not expected operation to fail but it did")
      end
    end

    it "raises an error when combining with :with_type chain" do
      dummy = double("Never called")

      expect do
        expect(dummy).not_to fail_on(input).with_type(:forbidden)
      end.to raise_error(
        NotImplementedError,
        "`expect().not_to fail_on(input).with_type()` is not supported."
      )
    end

    it "raises an error when combining with :with_message chain" do
      dummy = double("Never called")

      expect do
        expect(dummy).not_to fail_on(input).with_message("Nope")
      end.to raise_error(
        NotImplementedError,
        "`expect().not_to fail_on(input).with_message()` is not supported."
      )
    end

    it "raises an error when combining with :with_details chain" do
      dummy = double("Never called")

      expect do
        expect(dummy).not_to fail_on(input).with_details(name: ["is missing"])
      end.to raise_error(
        NotImplementedError,
        "`expect().not_to fail_on(input).with_details()` is not supported."
      )
    end
  end
end

require 'spec_helper'
require 'pathway/responder'

module Pathway
  describe Responder do

    describe ".respond" do
      context "when there's only a single 'failure' block," do
        let(:result) do
          Responder.respond(passed_result) do
            success { |value| "Returning: " + value }
            failure { |error| error}
          end
        end

        context "and the result is succesfull" do
          let(:passed_result) { Result.success("VALUE") }

          it "executes the success block" do
            expect(result).to eq("Returning: VALUE")
          end
        end

        context "and the result is unsuccesfull" do
          let(:passed_result) { Result.failure("AN ERROR!") }

          it "executes the failure block" do
            expect(result).to eq("AN ERROR!")
          end
        end
      end

      context "when there're many 'failure' blocks," do
        let(:result) do
          Responder.respond(passed_result) do
            success              { |value| "Returning: " + value }
            failure(:forbidden)  { |error| "Forbidden" }
            failure(:validation) { |error| "Invalid: " + error.errors.join(", ") }
            failure              { |error| "Other: " + error.errors.join(" ") }
          end
        end

        context "and the result is succesfull" do
          let(:passed_result) { Result.success("VALUE") }

          it "executes the success block" do
            expect(result).to eq("Returning: VALUE")
          end
        end

        context "and the result is an error of a specified type" do
          let(:passed_result) do
            Result.failure(Error.new(type: :validation, details: ['name missing', 'email missing']))
          end

          it "executes the right failure type block" do
            expect(result).to eq("Invalid: name missing, email missing")
          end
        end

        context "and the result is an error of an unspecified type" do
          let(:passed_result) { Result.failure(Error.new(type: :misc, details: %w[some errors])) }

          it "executes the general failure block " do
            expect(result).to eq("Other: some errors")
          end
        end
      end
    end

  end
end

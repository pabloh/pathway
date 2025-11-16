# frozen_string_literal: true

require "spec_helper"

module Pathway
  module Plugins
    describe "Responder" do
      class RespOperation < Operation
        plugin :responder

        context :with

        def call(_)
          with
        end
      end

      let(:input)   { {} }
      let(:context) { { with: passed_result } }

      describe ".call" do
        context "when no block is given" do
          let(:passed_result) { Result.success("VALUE") }
          let(:result) { RespOperation.(context, input) }

          it "instances an operation an executes 'call'", :aggregate_failures do
            expect(result).to be_kind_of(Pathway::Result)
            expect(result.value).to eq("VALUE")
          end
        end

        context "when a block is given" do
          context "provided with a single 'failure' block," do
            let(:result) do
              RespOperation.call(context, input) do
                success { |value| "Returning: " + value }
                failure { |error| error }
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

          context "provided with many 'failure' blocks," do
            let(:result) do
              RespOperation.call(context, input) do
                success              { |value| "Returning: " + value }
                failure(:forbidden)  { |error| "Forbidden" }
                failure(:validation) { |error| "Invalid: " + error.details.join(", ") }
                failure              { |error| "Other: " + error.details.join(" ") }
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
                Result.failure(Error.new(type: :validation, details: ["name missing", "email missing"]))
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
  end
end

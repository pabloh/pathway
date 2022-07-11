# frozen_string_literal: true

require 'spec_helper'

module Pathway
  class Result
    module Mixin
      describe 'Operation call with pattern matching' do
        class RespOperation < Operation
          context :with

          def call(_)
            with
          end
        end

        let(:input)   { {} }
        let(:context) { { with: passed_result } }

        context "when calling operation using 'case'" do
          context "providing a single variable name as pattern" do
            let(:result) do
              case RespOperation.call(context, input)
              in Success(value) then "Returning: " + value
              in Failure(error) then error.message
              end
            end

            context "and the result is succesfull" do
              let(:passed_result) { Result.success("VALUE") }

              it "returns the success result" do
                expect(result).to eq("Returning: VALUE")
              end
            end

            context "and the result is a failure" do
              let(:passed_result) { Result.failure(Error.new(type: :error, message: "AN ERROR!")) }

              it "returns the failure result" do
                expect(result).to eq("AN ERROR!")
              end
            end
          end


          context "providing Hash based patterns," do
            context "and the underlying result does not support Hash based patterns" do
              let(:passed_result) { Result.success("VALUE") }

              it "raises a non matching error" do
                expect {
                  case RespOperation.call(context, input)
                  in Success(value:) then value
                  in Failure(error) then error
                  end
                }.to raise_error(NoMatchingPatternError)
              end
            end

            let(:result) do
              case RespOperation.call(context, input)
              in Success(value) then "Returning: " + value
              in Failure(type: :forbidden) then "Forbidden"
              in Failure(type: :validation, details:) then "Invalid: " + details.join(", ")
              in Failure(details:) then "Other: " + details.join(" ")
              end
            end

            context "and the result is succesfull" do
              let(:passed_result) { Result.success("VALUE") }

              it "returns the success result" do
                expect(result).to eq("Returning: VALUE")
              end
            end

            context "the result is a failure" do
              context "and the pattern is Failure with only :type specified" do
                let(:passed_result) do
                  Result.failure(Error.new(type: :forbidden))
                end

                it "returns the result according to :type" do
                  expect(result).to eq("Forbidden")
                end
              end

              context "and the pattern is Failure with :type and :details specified" do
                let(:passed_result) do
                  Result.failure(Error.new(type: :validation, details: ['name missing', 'email missing']))
                end

                it "returns the result according to :type" do
                  expect(result).to eq("Invalid: name missing, email missing")
                end
              end

              context "and the pattern is Failure with no specified :type" do
                let(:passed_result) { Result.failure(Error.new(type: :misc, details: %w[some errors])) }

                it "executes the least specific pattern" do
                  expect(result).to eq("Other: some errors")
                end
              end
            end
          end

          context "providing Array based patterns," do
            let(:result) do
              case RespOperation.call(context, input)
              in Success(value) then "Returning: " + value
              in Failure([:forbidden,]) then "Forbidden"
              in Failure([:validation, _, details]) then "Invalid: " + details.join(", ")
              in Failure(type: :validation, details:) then "Invalid: " + details.join(", ")
              in Failure([*, details]) then "Other: " + details.join(" ")
              end
            end

            context "and the result is succesfull" do
              let(:passed_result) { Result.success("VALUE") }

              it "returns the success result" do
                expect(result).to eq("Returning: VALUE")
              end
            end

            context "the result is a failure" do
              context "and the pattern is Failure with only :type specified" do
                let(:passed_result) do
                  Result.failure(Error.new(type: :forbidden))
                end

                it "returns the result according to :type" do
                  expect(result).to eq("Forbidden")
                end
              end

              context "and the pattern is Failure with :type and :details specified" do
                let(:passed_result) do
                  Result.failure(Error.new(type: :validation, details: ['name missing', 'email missing']))
                end

                it "returns the result according to :type" do
                  expect(result).to eq("Invalid: name missing, email missing")
                end
              end

              context "and the pattern is Failure with no specified :type" do
                let(:passed_result) { Result.failure(Error.new(type: :misc, details: %w[some errors])) }

                it "executes the least specific pattern" do
                  expect(result).to eq("Other: some errors")
                end
              end
            end
          end
        end
      end
    end
  end
end

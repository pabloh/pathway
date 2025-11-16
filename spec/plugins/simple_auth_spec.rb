# frozen_string_literal: true

require "spec_helper"

module Pathway
  module Plugins
    describe "SimpleAuth" do
      class AuthOperation < Operation
        plugin :simple_auth

        context :user

        authorization { user.role == :admin }

        process do
          step :authorize
        end
      end

      class AuthOperationParam < Operation
        plugin :simple_auth

        context value: :RESULT

        authorization { |value| value == :RESULT }

        process do
          step :authorize
        end
      end

      class AuthOperationMultiParam < Operation
        plugin :simple_auth

        context :value1, :value2

        authorization { |first, second| first == 10 && second == 20 }

        process do
          step :authorize, using: %i[value1 value2]
        end
      end


      class AuthOperationWithArray < Operation
        plugin :simple_auth

        context :values

        authorization { |values| values.size.even? }

        process do
          step :authorize, using: :values
        end
      end

      describe "#authorize" do
        subject(:operation) { AuthOperationParam.new }

        context "with no options" do
          it "passes the current result to the authorization block to authorize", :aggregate_failures do
            expect(operation.authorize({ value: :RESULT })).to be_a_success
          end
        end

        context "with :using argument" do
          it "passes then value for :key from the context to the authorization block to authorize", :aggregate_failures do
            expect(operation.authorize({ foo: :RESULT }, using: :foo)).to be_a_success
            expect(operation.authorize({ foo: :ELSE }, using: :foo)).to be_a_failure
          end
        end
      end

      describe "#call" do
        context "when the authorization blocks expects no params" do
          subject(:operation) { AuthOperation.new(context) }
          let(:context) { { user: double(role: role) } }

          context "and calling with proper authorization" do
            let(:role) { :admin }
            it "returns a successful result", :aggregate_failures do
              expect(operation).to succeed_on({})
            end
          end

          context "and calling with without proper authorization" do
            let(:role) { :user }
            it "returns a failed result", :aggregate_failures do
              expect(operation).to fail_on({}).with_type(:forbidden)
            end
          end
        end

        context "when the authorization blocks expects a single param" do
          context "and calling with proper authorization" do
            subject(:operation) { AuthOperationParam.new }
            it "returns a successful result", :aggregate_failures do
              expect(operation).to succeed_on({})
            end
          end

          context "and calling without proper authorization" do
            subject(:operation) { AuthOperationParam.new(value: :OTHER) }
            it "returns a failed result", :aggregate_failures do
              expect(operation).to fail_on({}).with_type(:forbidden)
            end
          end
        end

        context "when the authorization blocks expects multiple params" do
          context "and calling with proper authorization" do
            subject(:operation) { AuthOperationMultiParam.new(value1: 10, value2: 20) }
            it "returns a successful result", :aggregate_failures do
              expect(operation).to succeed_on({})
            end
          end

          context "and calling without proper authorization" do
            subject(:operation) { AuthOperationMultiParam.new(value1: -11, value2: 99) }
            it "returns a failed result", :aggregate_failures do
              expect(operation).to fail_on({}).with_type(:forbidden)
            end
          end
        end

        context "when the authorization blocks expects an array as param" do
          context "and calling with proper authorization" do
            subject(:operation) { AuthOperationWithArray.new(values: [3, 5]) }
            it "returns a successful result", :aggregate_failures do
              expect(operation).to succeed_on({})
            end
          end

          context "and calling without proper authorization" do
            subject(:operation) { AuthOperationWithArray.new(values: [3, 4, 5]) }
            it "returns a failed result", :aggregate_failures do
              expect(operation).to fail_on({}).with_type(:forbidden)
            end
          end
        end
      end
    end
  end
end

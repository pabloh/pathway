require 'spec_helper'

module Pathway
  module Plugins
    describe 'Authorization' do
      class AuthOperation < Operation
        plugin :authorization

        context :user

        authorization { user.role == :admin }

        process do
          step :authorize
        end
      end

      class Auth2Operation < Operation
        plugin :authorization

        context value: :RESULT

        authorization { |value| value == :RESULT }

        process do
          step :authorize
        end
      end

      describe "#authorize" do
        subject(:operation) { Auth2Operation.new }

        context "with no options" do
          it "passes the current result to the authorization block to authorize", :aggregate_failures do
            expect(operation.authorize({value: :RESULT})).to be_a_success
          end
        end

        context "with :using argument" do
          it "passes then value for :key from the context to the authorization block to authorize", :aggregate_failures do
            expect(operation.authorize({foo: :RESULT}, using: :foo)).to be_a_success
            expect(operation.authorize({foo: :ELSE}, using: :foo)).to be_a_failure
          end
        end
      end

      describe "#call" do
        let(:result)  { operation.call({}) }

        context "when the authorization blocks expects no params" do
          subject(:operation) { AuthOperation.new(context) }
          let(:context) { { user: double(role: role) } }

          context "and calling with proper authorization" do
            let(:role) { :admin }
            it "returns a successful result", :aggregate_failures do
              expect(result).to be_a_success
            end
          end

          context "and calling with without proper authorization" do
            let(:role) { :user }
            it "returns a failed result", :aggregate_failures do
              expect(result).to be_a_failure
              expect(result.error.type).to eq(:forbidden)
            end
          end
        end


        context "when the authorization blocks expects params" do
          context "and calling with proper authorization" do
            subject(:operation) { Auth2Operation.new }
            it "returns a successful result", :aggregate_failures do
              expect(result).to be_a_success
            end
          end

          context "and calling without proper authorization" do
            subject(:operation) { Auth2Operation.new(value: :OTHER) }
            it "returns a failed result", :aggregate_failures do
              expect(result).to be_a_failure
              expect(result.error.type).to eq(:forbidden)
            end
          end
        end
      end
    end
  end
end

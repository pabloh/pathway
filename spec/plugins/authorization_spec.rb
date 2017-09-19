require 'spec_helper'

module Pathway
  module Plugins
    describe 'Authorization' do
      class AuthOperation < Operation
        plugin :authorization

        context :user, allow: false

        authorization { |value| value == :RESULT && user.role == :admin }

        process do
          set  :fetch_value
          step :authorize
        end

        private

        def fetch_value(**)
          :RESULT
        end
      end

      subject(:operation) { AuthOperation.new(context) }

      describe "#authorize" do
        let(:context) { { user: double(role: :admin) } }

        context "with no options" do
          it "uses authorization block and value to authorize", :aggregate_failures do
            expect(operation.authorize(value: :RESULT)).to be_a_success
          end
        end

        context "with :using argument" do
          it "uses authorization block and :using key to authorize", :aggregate_failures do
            expect(operation.authorize({foo: :RESULT}, using: :foo)).to be_a_success
            expect(operation.authorize({foo: :ELSE}, using: :foo)).to be_a_failure
          end
        end
      end

      describe "#call" do
        let(:context) { { user: double(role: role) } }
        let(:result)  { operation.call({}) }

        context "when calling with proper authorization" do
          let(:role) { :admin }
          it "returns a successful result", :aggregate_failures do
            expect(result).to be_a_success
            expect(result.value).to be(:RESULT)
          end
        end

        context "when calling with without proper authorization" do
          let(:role) { :user }
          it "returns a failed result", :aggregate_failures do
            expect(result).to be_a_failure
            expect(result.error.type).to eq(:forbidden)
          end
        end
      end
    end
  end
end

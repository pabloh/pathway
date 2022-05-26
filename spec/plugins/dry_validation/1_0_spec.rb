# frozen_string_literal: true

require 'spec_helper'
require 'dry/validation/version'

return unless Dry::Validation::VERSION =~ /^1\./

module Pathway
  module Plugins
    describe 'DryValidation::V1_0' do
      class SimpleOperation < Operation
        plugin :dry_validation

        context :user, :repository

        params do
          required(:name).filled(:string)
          optional(:email).maybe(:string)
        end

        process do
          step :validate
          set  :fetch_profile, to: :profile
          set  :create_model
        end

        private

        def fetch_profile(state)
          wrap_if_present(repository.fetch(state[:params]))
        end

        def create_model(state)
          params, profile = state.values_at(:params, :profile)
          SimpleModel.new(*params.values, user.role, profile)
        end
      end

      SimpleModel = Struct.new(:name, :email, :role, :profile)

      class SimpleContract < Dry::Validation::Contract
        params do
          required(:age).filled(:integer)
        end
      end

      class OperationWithOpt < Operation
        plugin :dry_validation

        context :quz

        contract do
          option :foo

          params do
            required(:qux).filled(:string)
          end

          rule(:qux) do
            key.failure('not equal to :foo') unless value == foo
          end
        end

        process do
          step :validate, with: { foo: :quz }
        end
      end

      class OperationWithAutoWire < Operation
        plugin :dry_validation, auto_wire_options: true

        context :baz

        contract do
          option :baz

          params do
            required(:qux).filled(:string)
          end

          rule(:qux) do
            key.failure('not equal to :foo') unless value == baz
          end
        end

        process do
          step :validate
        end
      end

      describe ".contract_class" do
        subject(:operation_class) { Class.new(Operation) { plugin :dry_validation } }

        context "when no contract's been setup" do
          it "returns a default empty contract" do
            expect(operation_class.contract_class).to eq(Dry::Validation::Contract)
          end
        end

        context "when a contract's been set" do
          it "returns the contract" do
            operation_class.contract_class = SimpleContract
            expect(operation_class.contract_class).to eq(SimpleContract)
          end
        end
      end

      describe ".build_contract" do
        let(:contract) { OperationWithOpt.build_contract(foo: "XXXXX") }

        it "uses passed the option from the context to the contract" do
          expect(contract.call(qux: "XXXXX")).to be_a_success
        end
      end

      describe ".contract_options" do
        it "returns the option names defined for the contract" do
          expect(SimpleOperation.contract_options).to eq([])
          expect(OperationWithOpt.contract_options).to eq([:foo])
        end
      end

      describe ".contract" do
        context "when called with a contract" do
          subject(:operation_class) do
            Class.new(Operation) do
              plugin :dry_validation
              contract SimpleContract
            end
          end

          it "uses the passed contract's class" do
            expect(operation_class.contract_class).to eq(SimpleContract)
          end

          context "and a block" do
            subject(:operation_class) do
              Class.new(Operation) do
                plugin :dry_validation
                contract(SimpleContract) do
                  params do
                    required(:gender).filled(:string)
                  end
                end
              end
            end

            it "extend from the contract's class" do
              expect(operation_class.contract_class).to be < SimpleContract
            end

            it "extends the contract rules with the block's rules" do
              expect(operation_class.contract_class.schema.rules.keys)
                .to include(:age, :gender)
            end
          end
        end

        context "when called with a block" do
          subject(:operation_class) do
            Class.new(Operation) do
              plugin :dry_validation
              contract do
                params do
                  required(:gender).filled(:string)
                end
              end
            end
          end

          it "extends from the default contract class" do
            expect(operation_class.contract_class).to be < Dry::Validation::Contract
          end

          it "uses the rules defined at the passed block" do
            expect(operation_class.contract_class.schema.rules.keys)
              .to include(:gender)
          end
        end
      end

      describe "#call" do
        subject(:operation) { SimpleOperation.new(ctx) }

        let(:ctx)        { { user: double("User", role: role), repository: repository } }
        let(:role)       { :root }
        let(:params)     { { name: "Paul Smith", email: "psmith@email.com" } }
        let(:result)     { operation.call(params) }
        let(:repository) { double.tap { |repo| allow(repo).to receive(:fetch).and_return(double) } }

        context "when calling with valid params" do
          it "returns a successful result", :aggregate_failures do
            expect(result).to be_a_success
            expect(result.value).to_not be_nil
          end
        end

        context "when finding model fails" do
          let(:repository) { double.tap { |repo| allow(repo).to receive(:fetch).and_return(nil) } }
          it "returns a a failed result", :aggregate_failures do
            expect(result).to be_a_failure
            expect(result.error.type).to eq(:not_found)
          end
        end

        context "when calling with invalid params" do
          let(:params) { { email: "psmith@email.com" } }
          it "returns a failed result", :aggregate_failures do
            expect(result).to be_a_failure
            expect(result.error.type).to eq(:validation)
            expect(result.error.details).to eq(name: ['is missing'])
          end
        end

        context "when contract requires options for validation" do
          subject(:operation) { OperationWithOpt.new(quz: 'XXXXX') }

          it "sets then passing a hash through the :with argument" do
            expect(operation.call(qux: 'XXXXX')).to be_a_success
            expect(operation.call(qux: 'OTHER')).to be_a_failure
          end

          context "and is using auto_wire_options" do
            subject(:operation) { OperationWithAutoWire.new(baz: 'XXXXX') }

            it "sets the options directly from the context using the keys with the same name" do
              expect(operation.call(qux: 'XXXXX')).to be_a_success
              expect(operation.call(qux: 'OTHER')).to be_a_failure
            end
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'
require 'dry/validation/version'

return unless Dry::Validation::VERSION =~ /^0\.11/

module Pathway
  module Plugins
    describe 'DryValidation::V0_11' do
      class SimpleOperation < Operation
        plugin :dry_validation

        context :user, :repository

        form do
          required(:name).filled(:str?)
          optional(:email).maybe(:str?)
        end

        process do
          step :validate
          set  :fetch_profile, to: :profile
          set  :create_model
        end

        private

        def fetch_profile(params:,**)
          wrap_if_present(repository.fetch(params))
        end

        def create_model(params:, profile:,**)
          SimpleModel.new(*params.values, user.role, profile)
        end
      end

      SimpleModel = Struct.new(:name, :email, :role, :profile)

      SimpleForm = Dry::Validation.Form do
        required(:age).filled(:int?)
      end

      class OperationWithOpt < Operation
        plugin :dry_validation

        context :quz

        form do
          configure { option :foo }

          required(:qux).filled(eql?: foo)
        end

        process do
          step :validate, with: { foo: :quz }
        end
      end

      class OperationWithAutoWire < Operation
        plugin :dry_validation, auto_wire_options: true

        context :baz

        form do
          configure { option :baz }

          required(:qux).filled(eql?: baz)
        end

        process do
          step :validate
        end
      end

      describe ".form_class" do
        subject(:operation_class) { Class.new(Operation) { plugin :dry_validation } }

        context "when no form's been setup" do
          it "returns a default empty form" do
            expect(operation_class.form_class).to eq(Dry::Validation::Schema::Form)
          end
        end

        context "when a form's been set" do
          it "returns the form" do
            operation_class.form_class = SimpleForm
            expect(operation_class.form_class).to eq(SimpleForm)
          end
        end
      end

      describe ".build_form" do
        let(:form) { OperationWithOpt.build_form(foo: "XXXXX") }

        it "uses passed the option from the context to the form" do
          expect(form.call(qux: "XXXXX")).to be_a_success
        end
      end

      describe ".form_options" do
        it "returns the option names defined for the form" do
          expect(SimpleOperation.form_options).to eq([])
          expect(OperationWithOpt.form_options).to eq([:foo])
        end
      end

      describe ".form" do
        context "when called with a form" do
          subject(:operation_class) do
            Class.new(Operation) do
              plugin :dry_validation
              form SimpleForm
            end
          end

          it "uses the passed form's class" do
            expect(operation_class.form_class).to eq(SimpleForm.class)
          end

          context "and a block" do
            subject(:operation_class) do
              Class.new(Operation) do
                plugin :dry_validation
                form(SimpleForm) { required(:gender).filled }
              end
            end

            it "extend from the form's class" do
              expect(operation_class.form_class).to be < SimpleForm.class
            end

            it "extends the form rules with the block's rules" do
              expect(operation_class.form_class.rules.map(&:name))
                .to include(:age, :gender)
            end
          end
        end

        context "when called with a form class" do
          subject(:operation_class) do
            Class.new(Operation) do
              plugin :dry_validation
              form SimpleForm.class
            end
          end

          it "uses the passed class as is" do
            expect(operation_class.form_class).to eq(SimpleForm.class)
          end
        end

        context "when called with a block" do
          subject(:operation_class) do
            Class.new(Operation) do
              plugin :dry_validation
              form { required(:gender).filled }
            end
          end

          it "extends from the default form class" do
            expect(operation_class.form_class).to be < Dry::Validation::Schema::Form
          end

          it "uses the rules defined at the passed block" do
            expect(operation_class.form_class.rules.map(&:name))
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

        context "when form requires options for validation" do
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

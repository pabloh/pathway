require 'spec_helper'

module Pathway
  module Plugins
    describe 'SequelModels' do
      DB = Sequel.mock
      MyModel = Class.new(Sequel::Model(DB[:foo])) { set_primary_key :pk }

      class PkOperation < Operation
        plugin :sequel_models, model: MyModel
      end

      class MyOperation < Operation
        plugin :sequel_models

        context mailer: nil

        model MyModel, search_by: :email

        process do
          transaction do
            step :fetch_model
            after_commit do
              step :send_emails
            end
          end
        end

        def send_emails(my_model:,**)
          @mailer.send_emails(my_model) if @mailer
        end
      end

      class SubOperation < MyOperation; end

      let(:mailer) { double.tap { |d| allow(d).to receive(:send_emails) } }
      let(:operation) { MyOperation.new(mailer: mailer) }

      describe 'DSL' do
        let(:result) { operation.call(params) }
        let(:params) { { email: 'asd@fgh.net' } }
        let(:model)  { double }

        describe '#transaction' do
          it 'returns the result state provided by the inner transaction when successful' do
            allow(MyModel).to receive(:first).with(params).and_return(model)

            expect(result).to be_a_success
            expect(result.value).to eq(model)
          end

          it "returns the error state provided by the inner transaction when there's a failure" do
            allow(MyModel).to receive(:first).with(params).and_return(nil)

            expect(result).to be_a_failure
            expect(result.error.type).to eq(:not_found)
          end
        end

        describe '#after_commit' do
          it 'calls after_commit block when transaction is successful' do
            allow(MyModel).to receive(:first).with(params).and_return(model)
            expect(mailer).to receive(:send_emails).with(model)

            expect(result).to be_a_success
          end

          it 'does not call after_commit block when transaction fails' do
            allow(MyModel).to receive(:first).with(params).and_return(nil)

            expect(mailer).to_not receive(:send_emails)
            expect(result).to be_a_failure
          end
        end
      end

      describe '.model' do
        it "sets the 'result_key' using the model class name" do
          expect(operation.result_key).to eq(:my_model)
        end

        it "sets the 'model_class' using the first parameter" do
          expect(operation.model_class).to eq(MyModel)
        end

        context 'when a :search_field option is specified' do
          it "sets the 'search_field' with the provided value" do
            expect(operation.search_field).to eq(:email)
          end
        end

        context 'when no :search_field option is specified' do
          let(:operation) { PkOperation.new }

          it "sets the 'search_field' from the model's pk" do
            expect(operation.search_field).to eq(:pk)
          end
        end

        context 'when the operation is inherited' do
          it "sets 'result_key', 'search_field', 'model_class' and 'model_not_found' from the superclass" do
            aggregate_failures do
              expect(SubOperation.result_key).to eq(MyOperation.result_key)
              expect(SubOperation.search_field).to eq(MyOperation.search_field)
              expect(SubOperation.model_class).to eq(MyOperation.model_class)
              expect(SubOperation.model_not_found).to eq(MyOperation.model_not_found)
            end
          end
        end
      end

      describe '#db' do
        it 'returns the current db form the model class'  do
          expect(operation.db).to eq(DB)
        end
      end

      let(:key)    { 'some@email.com' }
      let(:params) { { foo: 3, bar: 4} }

      describe '#find_model_with' do
        it "queries the db through the 'model_class'" do
          expect(MyModel).to receive(:first).with(email: key)

          operation.find_model_with(key)
        end
      end

      describe '#fetch_model' do
        let(:from_model) { double(name: 'Model') }
        let(:object) { double }

        it "fetches an instance through 'model_class' into result key" do
          expect(MyModel).to receive(:first).with(email: key).and_return(object)

          expect(operation.fetch_model(input: {email: key}).value[:my_model]).to eq(object)
        end

        it "fetches an instance through 'model_class' and sets result key using an overrided search column, input key and 'from' model when provided" do
          expect(from_model).to receive(:first).with(pk: 'foo').and_return(object)
          expect(MyModel).to_not receive(:first)

          state  = { input: { myid: 'foo' } }
          result = operation
                     .fetch_model(state, from: from_model, using: :myid, search_by: :pk)
                     .value[:my_model]

          expect(result).to eq(object)
        end


        it "fetches an instance through 'model_class' and sets result key using an overrided search column and input key with only :search_by is provided" do
          expect(MyModel).to receive(:first).with(name: 'foobar').and_return(object)

          state  = { input: { email: 'other@email.com', name: 'foobar' } }
          result = operation
                     .fetch_model(state, search_by: :name)
                     .value[:my_model]

          expect(result).to eq(object)
        end

        it "fetches an instance through 'model_class' and sets result key using an overrided input key with but not search column when only :using is provided" do
          expect(MyModel).to receive(:first).with(email: 'foobar@mail.com').and_return(object)

          state  = { input: { email: 'other@email.com', first_email: 'foobar@mail.com' } }
          result = operation
                     .fetch_model(state, using: :first_email)
                     .value[:my_model]

          expect(result).to eq(object)
        end

        it 'returns an error when no instance is found', :aggregate_failures do
          expect(MyModel).to receive(:first).with(email: key).and_return(nil)

          result = operation.fetch_model(input: {email: key})

          expect(result).to be_an(Result::Failure)
          expect(result.error).to be_an(Pathway::Error)
          expect(result.error.type).to eq(:not_found)
          expect(result.error.message).to eq('My model not found')
        end

        it 'returns an error without hitting the database when search key is nil', :aggregate_failures do
          expect(MyModel).to_not receive(:first)

          result = operation.fetch_model(input: {email: nil})

          expect(result).to be_an(Result::Failure)
          expect(result.error).to be_an(Pathway::Error)
          expect(result.error.type).to eq(:not_found)
          expect(result.error.message).to eq('My model not found')
        end
      end

      describe '#call' do
        class CtxOperation < MyOperation
          context my_model: nil
        end

        let(:operation)     { CtxOperation.new(ctx) }
        let(:result)        { operation.call(email: 'an@email.com') }
        let(:fetched_model) { MyModel.new }

        context 'when the model is not present at the context' do
          let(:ctx) { {} }
          it 'fetchs the model from the DB' do
            expect(MyModel).to receive(:first).with(email: 'an@email.com').and_return(fetched_model)

            expect(result.value).to be(fetched_model)
          end
        end

        context 'when the model is already present in the context' do
          let(:existing_model) { MyModel.new }
          let(:ctx)            { { my_model: existing_model } }

          it 'uses the model from the context and avoid querying the DB' do
            expect(MyModel).to_not receive(:first)

            expect(result.value).to be(existing_model)
          end

          context 'but overwrite: option in step is true' do
            class OwOperation < CtxOperation
              process do
                step :fetch_model, overwrite: true
              end
            end

            let(:operation) { OwOperation.new(ctx) }

            it 'fetches the model from the DB anyway' do
              expect(MyModel).to receive(:first).with(email: 'an@email.com').and_return(fetched_model)

              expect(operation.my_model).to be(existing_model)
              expect(result.value).to be(fetched_model)
            end
          end
        end
      end

    end
  end
end

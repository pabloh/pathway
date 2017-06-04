require 'spec_helper'

module Pathway
  class Operation
    describe Finder do
      let(:model_class) { double(db: db, name: 'MyModel') }
      let(:db) { Sequel.mock }

      describe '.[]' do
        let(:result) { Finder[model_class] }
        it "returns a module" do
          expect(result).to be_a(Module)
        end

        context 'when including the resulting module' do
          let(:opts) { { by: :email } }
          let(:operation_class) {
            finder_mod = Finder[model_class, opts]
            Class.new(Operation) { include finder_mod }
          }
          let(:operation) { operation_class.new }

          it 'resets the :result_key using the model class name' do
            expect(operation.result_key).to eq(:my_model)
          end

          it "defines instance methods returning the config options", :aggregate_failures do
            expect(operation.model_class).to eq(model_class)
            expect(operation.field).to eq(:email)
            expect(operation.db).to eq(db)
          end

          let(:key)    { "some@email.com" }
          let(:params) { { foo: 3, bar: 4} }
          let(:object) { double }

          it "defines instance method 'find_model_with' to invoke model_class" do
            expect(model_class).to receive(:first).with(email: key)

            operation.find_model_with(key)
          end

          it "defines instance method 'build_model_with' to build model from model_class" do
            expect(model_class).to receive(:new).with(params)

            operation.build_model_with(params)
          end

          it "defines instance method 'fetch_model_with' to fetch object from model_class" do
            allow(model_class).to receive(:first).with(email: key).and_return(object)

            expect(operation.fetch_model_with(email: key)).to be_an(Result::Success)
            expect(operation.fetch_model_with(email: key).value).to eq(object)
          end

          it "defines instance method 'fetch_model_with' to return error when object is missing", :aggregate_failures do
            allow(model_class).to receive(:first).with(email: key).and_return(nil)

            expect(operation.fetch_model_with(email: key)).to be_an(Result::Failure)
            expect(operation.fetch_model_with(email: key).error).to be_an(Pathway::Error)
            expect(operation.fetch_model_with(email: key).error.type).to eq(:not_found)
          end

          it "defines instance method 'in_transaction' to return the original result on error" do
            error = Result.failure('VALUE')
            res = operation.wrap_transaction { error }

            expect(res).to eq(error)
          end
        end

      end
    end
  end
end

require 'spec_helper'

module Pathway
  module Plugins
    describe 'SequelModels' do
      DB = Sequel.mock
      MyModel = Class.new(Sequel::Model(DB[:foo]))

      class MyOperation < Operation
        plugin :sequel_models

        include Finder[MyModel, by: :email]

        process do
          transaction do
            step :fetch_model
          end
        end
      end

      let(:operation) { MyOperation.new }

      describe "DSL" do
        describe "#transaction" do
          let(:result) { operation.call(params) }
          let(:params) { { email: 'asd@fgh.net' } }
          let(:model)  { double }

          it "returns the result state provided by the inner transaction when successful" do
            allow(MyModel).to receive(:first).with(params).and_return(model)

            expect(result).to be_a_success
            expect(result.value).to eq(model)
          end

          it "returns the error state provided by the inner transaction when there's a failure" do
            expect(result).to be_a_failure
            expect(result.error.type).to eq(:not_found)
          end
        end
      end

      describe '.[]' do
        context 'when including the resulting module' do
          it 'resets the :result_key using the model class name' do
            expect(operation.result_key).to eq(:my_model)
          end

          it "defines instance methods returning the config options", :aggregate_failures do
            expect(operation.model_class).to eq(MyModel)
            expect(operation.field).to eq(:email)
            expect(operation.db).to eq(DB)
          end

          let(:key)    { "some@email.com" }
          let(:params) { { foo: 3, bar: 4} }
          let(:object) { double }

          it "defines instance method 'find_model_with' to invoke model_class" do
            expect(MyModel).to receive(:first).with(email: key)

            operation.find_model_with(key)
          end

          it "defines instance method 'build_model_with' to build model from model_class" do
            expect(MyModel).to receive(:new).with(params)

            operation.build_model_with(params)
          end

          let(:repository) { double }

          it "defines instance method 'fetch_model' step to fetch object from model_class into result key" do
            expect(repository).to receive(:first).with(pk: 'foo').and_return(object)
            expect(MyModel).to_not receive(:first)

            result = operation
                       .fetch_model({input: {myid: 'foo'}}, from: repository, key: :myid, column: :pk)
                       .value[:my_model]

            expect(result).to eq(object)
          end


          it "defines instance method 'fetch_model' step to fetch object from model_class into result key using default arguments when none specified" do
            expect(MyModel).to receive(:first).with(email: key).and_return(object)

            expect(operation.fetch_model(input: {email: key}).value[:my_model]).to eq(object)
          end

          it "defines instance method 'fetch_model' to return error when object is missing", :aggregate_failures do
            allow(MyModel).to receive(:first).with(email: key).and_return(nil)

            expect(operation.fetch_model(input: {email: key})).to be_an(Result::Failure)
            expect(operation.fetch_model(input: {email: key}).error).to be_an(Pathway::Error)
            expect(operation.fetch_model(input: {email: key}).error.type).to eq(:not_found)
          end
        end

      end
    end
  end
end

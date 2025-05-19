# frozen_string_literal: true

require 'spec_helper'

module Pathway
  module Plugins
    describe 'AutoDeconstructState' do
      class KwargsOperation < Operation
        plugin :auto_deconstruct_state

        context :validator, :name_repo, :email_repo, :notifier

        process do
          step :custom_validate
          step :fetch_and_set_name, with: :id
          set  :fetch_email, to: :email
          set  :create_model
          step :notify
        end

        def custom_validate(state)
          state[:params] = @validator.call(state[:input])
        end

        def fetch_and_set_name(state, with:)
          state[:name] = @name_repo.call(state[:params][with])
        end

        def fetch_email(name:, **, &_)
          @email_repo.call(name)
        end

        def create_model(name:, email:, **)
          UserModel.new(name, email)
        end

        def notify(s)
          s.u do |value:|
            @notifier.call(value)
          end
        end
      end

      UserModel = Struct.new(:name, :email)

      describe "#call" do
        subject(:operation) { KwargsOperation.new(ctx) }

        let(:ctx)        { { validator: validator, name_repo: name_repo, email_repo: email_repo, notifier: notifier } }
        let(:name)       { 'Paul Smith' }
        let(:email)      { 'psmith@email.com' }
        let(:input)      { { id: 99 } }

        let(:validator) do
          double.tap do |val|
            allow(val).to receive(:call) do |input_arg|
              expect(input_arg).to eq(input)

              input
            end
          end
        end

        let(:name_repo) do
          double.tap do |repo|
            allow(repo).to receive(:call).with(99).and_return(name)
          end
        end

        let(:email_repo) do
          double.tap do |repo|
            allow(repo).to receive(:call).with(name).and_return(email)
          end
        end

        let(:notifier) do
          double.tap do |repo|
            allow(repo).to receive(:call) do |value|
              expect(value).to be_a(UserModel).and(have_attributes(name: name, email: email))
            end
          end
        end

        it 'destructure arguments on steps with only kwargs', :aggregate_failures do
          operation.call(input)
        end
      end
    end
  end
end

# frozen_string_literal: true

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
          step :fetch_model
        end
      end

      class MailerOperation < MyOperation
        process do
          transaction do
            step :fetch_model
            after_commit do
              step :send_emails
            end
          end
          step :as_hash
        end

        def as_hash(state)
          state[:my_model] = { model: state[:my_model] }
        end

        def send_emails(state)
          @mailer.send_emails(state[:my_model]) if @mailer
        end
      end

      class ChainedOperation < MyOperation
        result_at :result

        process do
          transaction do
            set :chain_operation, to: :result
          end
        end

        def chain_operation(state)
          MailerOperation.call(context, state[:input])
        end
      end

      describe 'DSL' do
        let(:params) { { email: 'asd@fgh.net' } }
        let(:model)  { double }

        let(:mailer) { double.tap { |d| allow(d).to receive(:send_emails) } }

        describe '#transaction' do
          context 'when providing a block' do
            let(:operation) { MailerOperation.new(mailer: mailer) }
            before { allow(DB).to receive(:transaction).and_call_original }

            it 'returns the result state provided by the inner transaction when successful' do
              allow(MyModel).to receive(:first).with(params).and_return(model)

              expect(operation).to succeed_on(params).returning(model: model)
            end

            it "returns the error state provided by the inner transaction when there's a failure" do
              allow(MyModel).to receive(:first).with(params).and_return(nil)

              expect(operation).to fail_on(params).with_type(:not_found)
            end

            context 'a conditional,' do
              class IfConditionalOperation < PkOperation
                context :should_run

                process do
                  transaction(if: :should_run?) do
                    step :fetch_model
                  end
                end

                private
                def should_run?(state)= state[:should_run]
              end

              let(:operation) { IfConditionalOperation.new(should_run: should_run) }
              let(:params) { { pk: 77 } }

              context 'when the condition is true' do
                let(:should_run) { true }

                it 'executes the transaction' do
                  expect(DB).to receive(:transaction).once.and_call_original
                  expect(MyModel).to receive(:first).with(params).and_return(model)

                  expect(operation).to succeed_on(params).returning(model)
                end
              end

              context 'when the condition is false' do
                let(:should_run) { false }

                it 'skips the transaction' do
                  expect(MyModel).to_not receive(:first)
                  expect(DB).to_not receive(:transaction)

                  expect(operation).to succeed_on(params)
                end
              end
            end
          end

          context 'when providing a step' do
            class FetchStepOperation < MyOperation
              process do
                transaction :fetch_model
              end
            end

            let(:operation) { FetchStepOperation.new(mailer: mailer) }
            before { allow(DB).to receive(:transaction).and_call_original }

            it 'returns the result state provided by the inner transaction when successful' do
              allow(MyModel).to receive(:first).with(params).and_return(model)

              expect(operation).to succeed_on(params).returning(model)
            end

            it "returns the error state provided by the inner transaction when there's a failure" do
              allow(MyModel).to receive(:first).with(params).and_return(nil)

              expect(operation).to fail_on(params).with_type(:not_found)
            end

            context 'and conditional' do
              class UnlessConditionalOperation < PkOperation
                context :should_skip

                process do
                  transaction :create_model, unless: :should_skip?
                end

                def create_model(state)
                  state[result_key] = model_class.create(state[:input])
                end

                private
                def should_skip?(state)= state[:should_skip]
              end

              let(:operation) { UnlessConditionalOperation.new(should_skip: should_skip) }
              let(:params) { { pk: 99 } }

              context 'if the condition is true' do
                let(:should_skip) { false }

                it 'executes the transaction' do
                  expect(DB).to receive(:transaction).once.and_call_original
                  expect(MyModel).to receive(:create).with(params).and_return(model)

                  expect(operation).to succeed_on(params).returning(model)
                end
              end

              context 'if the condition is false' do
                let(:should_skip) { true }

                it 'skips the transaction' do
                  expect(DB).to_not receive(:transaction)
                  expect(MyModel).to_not receive(:create)

                  expect(operation).to succeed_on(params)
                end
              end
            end
          end

          context 'when both an :if and :unless conditional' do
            class InvalidUseOfCondOperation < MyOperation
              process do
                transaction :perform_db_action, if: :is_good?, unless: :is_bad?
              end
            end

            let(:operation) { InvalidUseOfCondOperation.new }

            it 'raises an error' do
              expect { operation.call(params) }.to raise_error.
                with_message('options :if and :unless are mutually exclusive')
            end
          end

          context 'when providing a block and a step' do
            class AmbivalentTransactOperation < MyOperation
              process do
                transaction :perform_db_action do
                  step :perform_other_db_action
                end
              end
            end

            let(:operation) { AmbivalentTransactOperation.new }

            it 'raises an error' do
              expect { operation.call(params) }.to raise_error
                .with_message('must provide either a step or a block but not both')
            end
          end

          context 'when not providing a block nor a step' do
            class EmptyTransacOperation < MyOperation
              process do
                transaction
              end
            end

            let(:operation) { EmptyTransacOperation.new }

            it 'raises an error' do
              expect { operation.call(params) }.to raise_error.
                with_message('must provide either a step or a block but not both')
            end
          end
        end

        describe '#after_commit' do
          context 'when providing a block' do
            let(:operation) { MailerOperation.new(mailer: mailer) }

            it 'calls after_commit block when transaction is successful' do
              expect(DB).to receive(:transaction).and_call_original
              allow(MyModel).to receive(:first).with(params).and_return(model)
              expect(DB).to receive(:after_commit).and_call_original
              expect(mailer).to receive(:send_emails).with(model)

              expect(operation).to succeed_on(params)
            end

            it 'does not call after_commit block when transaction fails' do
              expect(DB).to receive(:transaction).and_call_original
              allow(MyModel).to receive(:first).with(params).and_return(nil)
              expect(DB).to_not receive(:after_commit).and_call_original
              expect(mailer).to_not receive(:send_emails)

              expect(operation).to fail_on(params)
            end

            context 'and the execution state is changed bellow the after_commit callback' do
              let(:operation) { ChainedOperation.new(mailer: mailer) }

              it 'ignores any state changes that took place following the after_commit block' do
                allow(MyModel).to receive(:first).with(params).and_return(model)
                expect(mailer).to receive(:send_emails).with(model)

                expect(operation).to succeed_on(params).returning(model: model)
              end
            end
          end

          context 'when providing a step' do
            class SendEmailStepOperation < MyOperation
              process do
                transaction do
                  step :fetch_model
                  after_commit :send_emails
                end
              end

              def send_emails(state)
                @mailer.send_emails(state[:my_model]) if @mailer
              end
            end

            let(:operation) { SendEmailStepOperation.new(mailer: mailer) }
            before { expect(DB).to receive(:transaction).and_call_original }

            it 'calls after_commit block when transaction is successful' do
              allow(MyModel).to receive(:first).with(params).and_return(model)
              expect(DB).to receive(:after_commit).and_call_original
              expect(mailer).to receive(:send_emails).with(model)

              expect(operation).to succeed_on(params)
            end

            it 'does not call after_commit block when transaction fails' do
              allow(MyModel).to receive(:first).with(params).and_return(nil)
              expect(DB).to_not receive(:after_commit).and_call_original
              expect(mailer).to_not receive(:send_emails)

              expect(operation).to fail_on(params)
            end
          end

          context 'with conditional execution' do
            context 'using :if with and a block' do
              class IfConditionalAfterCommitOperation < MyOperation
                context :should_run

                process do
                  transaction do
                    step :fetch_model
                    after_commit(if: :should_run?) do
                      step :send_emails
                    end
                  end
                end

                def send_emails(state)
                  @mailer.send_emails(state[:my_model]) if @mailer
                end

                private
                def should_run?(state) = state[:should_run]
              end

              let(:operation) { IfConditionalAfterCommitOperation.new(mailer: mailer, should_run: should_run) }
              let(:params) { { email: 'asd@fgh.net' } }

              before { allow(MyModel).to receive(:first).with(params).and_return(model) }

              context 'when the condition is true' do
                let(:should_run) { true }

                it 'executes the after_commit block' do
                  expect(DB).to receive(:after_commit).and_call_original
                  expect(mailer).to receive(:send_emails).with(model)

                  expect(operation).to succeed_on(params)
                end
              end

              context 'when the condition is false' do
                let(:should_run) { false }

                it 'skips the after_commit block' do
                  expect(DB).to_not receive(:after_commit)
                  expect(mailer).to_not receive(:send_emails)

                  expect(operation).to succeed_on(params)
                end
              end
            end

            context 'using :unless and a block' do
              class UnlessConditionalAfterCommitOperation < MyOperation
                context :should_skip

                process do
                  transaction do
                    step :fetch_model
                    after_commit(unless: :should_skip?) do
                      step :send_emails
                    end
                  end
                end

                def send_emails(state)
                  @mailer.send_emails(state[:my_model]) if @mailer
                end

                private
                def should_skip?(state) = state[:should_skip]
              end

              let(:operation) { UnlessConditionalAfterCommitOperation.new(mailer: mailer, should_skip: should_skip) }
              let(:params) { { email: 'asd@fgh.net' } }

              before { allow(MyModel).to receive(:first).with(params).and_return(model) }

              context 'when the condition is false' do
                let(:should_skip) { false }

                it 'executes the after_commit block' do
                  expect(DB).to receive(:after_commit).and_call_original
                  expect(mailer).to receive(:send_emails).with(model)

                  expect(operation).to succeed_on(params)
                end
              end

              context 'when the condition is true' do
                let(:should_skip) { true }

                it 'skips the after_commit block' do
                  expect(DB).to_not receive(:after_commit)
                  expect(mailer).to_not receive(:send_emails)

                  expect(operation).to succeed_on(params)
                end
              end
            end

            context 'using :if with step name' do
              class IfStepConditionalAfterCommitOperation < MyOperation
                context :should_run

                process do
                  transaction do
                    step :fetch_model
                    after_commit :send_emails, if: :should_run?
                  end
                end

                def send_emails(state)
                  @mailer.send_emails(state[:my_model]) if @mailer
                end

                private
                def should_run?(state) = state[:should_run]
              end

              before { allow(MyModel).to receive(:first).with(email: 'asd@fgh.net').and_return(model) }
              let(:operation) { IfStepConditionalAfterCommitOperation.new(mailer: mailer, should_run: should_run) }

              context 'when the condition is true' do
                let(:should_run) { true }

                it 'executes the after_commit step' do
                  expect(DB).to receive(:after_commit).and_call_original
                  expect(mailer).to receive(:send_emails).with(model)

                  expect(operation).to succeed_on(params)
                end
              end

              context 'when the condition is false' do
                let(:should_run) { false }

                it 'skips the after_commit step' do
                  expect(DB).to_not receive(:after_commit)
                  expect(mailer).to_not receive(:send_emails)

                  expect(operation).to succeed_on(params)
                end
              end
            end

            context 'when both :if and :unless are provided' do
              class InvalidConditionalAfterCommitOperation < MyOperation
                process do
                  transaction do
                    after_commit :send_emails, if: :is_good?, unless: :is_bad?
                  end
                end
              end

              let(:operation) { InvalidConditionalAfterCommitOperation.new }

              it 'raises an error' do
                expect { operation.call(params) }.to raise_error
                  .with_message('options :if and :unless are mutually exclusive')
              end
            end
          end

          context 'when providing a block and a step' do
            class AmbivalentAfterCommitOperation < MyOperation
              process do
                transaction do
                  after_commit :perform_db_action do
                    step :perform_other_db_action
                  end
                end
              end
            end

            let(:operation) { AmbivalentAfterCommitOperation.new }

            it 'raises an error' do
              expect { operation.call(params) }.to raise_error
                .with_message('must provide either a step or a block but not both')
            end
          end

          context 'when not providing a block nor a step' do
            class InvalidAfterCommitOperation < MyOperation
              process do
                transaction do
                  after_commit
                end
              end
            end

            let(:operation) { InvalidAfterCommitOperation.new }

            it 'raises an error' do
              expect { operation.call(params) }.to raise_error.
                with_message('must provide either a step or a block but not both')
            end
          end
        end

        describe '#after_rollback' do
          class LoggerOperation < MyOperation
            context :logger

            process do
              transaction do
                after_rollback do
                  step :log_error
                end

                step :fetch_model
              end
            end

            def log_error(_)
              @logger.log("Ohhh noes!!!!")
            end
          end

          let(:logger) { double }

          context 'when providing a block' do
            class RollbackWithBlockOperation < LoggerOperation
              process do
                transaction do
                  after_rollback do
                    step :log_error
                  end

                  step :fetch_model
                end
              end
            end

            let(:operation) { RollbackWithBlockOperation.new(logger: logger) }
            before { expect(DB).to receive(:transaction).and_call_original }

            it 'calls after_rollback block when transaction fails' do
              expect(MyModel).to receive(:first).with(params).and_return(nil)
              expect(logger).to receive(:log)

              expect(operation).to fail_on(params)
            end

            it 'does not call after_rollback block when transaction succeeds' do
              expect(MyModel).to receive(:first).with(params).and_return(model)
              expect(logger).to_not receive(:log)

              expect(operation).to succeed_on(params)
            end
          end

          context 'when providing a step' do
            class RollbackStepOperation < LoggerOperation
              process do
                transaction do
                  after_rollback :log_error
                  step :fetch_model
                end
              end
            end

            let(:operation) { RollbackStepOperation.new(logger: logger) }
            before { expect(DB).to receive(:transaction).and_call_original }

            it 'calls after_rollback step when transaction fails' do
              expect(MyModel).to receive(:first).with(params).and_return(nil)
              expect(logger).to receive(:log)

              expect(operation).to fail_on(params)
            end

            it 'does not call after_rollback step when transaction succeeds' do
              expect(MyModel).to receive(:first).with(params).and_return(model)
              expect(logger).to_not receive(:log)

              expect(operation).to succeed_on(params)
            end
          end

          context 'with conditional execution' do
            context 'using :if with a block' do
              class IfConditionalAfterRollbackOperation < LoggerOperation
                context :should_run

                process do
                  transaction do
                    after_rollback(if: :should_run?) do
                      step :log_error
                    end
                    step :fetch_model
                  end
                end

                private
                def should_run?(state) = state[:should_run]
              end

              let(:operation) { IfConditionalAfterRollbackOperation.new(logger: logger, should_run: should_run) }
              let(:params) { { email: 'asd@fgh.net' } }

              before { allow(MyModel).to receive(:first).with(params).and_return(nil) }

              context 'when the condition is true' do
                let(:should_run) { true }

                it 'executes the after_rollback block' do
                  expect(logger).to receive(:log)

                  expect(operation).to fail_on(params)
                end
              end

              context 'when the condition is false' do
                let(:should_run) { false }

                it 'skips the after_rollback block' do
                  expect(DB).to_not receive(:after_rollback)
                  expect(logger).to_not receive(:log)

                  expect(operation).to fail_on(params)
                end
              end
            end

            context 'using :unless with a block' do
              class UnlessConditionalAfterRollbackOperation < LoggerOperation
                context :should_skip

                process do
                  transaction do
                    after_rollback(unless: :should_skip?) do
                      step :log_error
                    end
                    step :fetch_model
                  end
                end

                private
                def should_skip?(state) = state[:should_skip]
              end

              let(:operation) { UnlessConditionalAfterRollbackOperation.new(logger: logger, should_skip: should_skip) }
              let(:params) { { email: 'asd@fgh.net' } }

              before { allow(MyModel).to receive(:first).with(params).and_return(nil) }

              context 'when the condition is false' do
                let(:should_skip) { false }

                it 'executes the after_rollback block' do
                  expect(logger).to receive(:log)

                  expect(operation).to fail_on(params)
                end
              end

              context 'when the condition is true' do
                let(:should_skip) { true }

                it 'skips the after_rollback block' do
                  expect(DB).to_not receive(:after_rollback)
                  expect(logger).to_not receive(:log)

                  expect(operation).to fail_on(params)
                end
              end
            end

            context 'using :if with step name' do
              class IfStepConditionalAfterRollbackOperation < LoggerOperation
                context :should_run

                process do
                  transaction do
                    after_rollback :log_error, if: :should_run?
                    step :fetch_model
                  end
                end

                private
                def should_run?(state) = state[:should_run]
              end

              before { allow(MyModel).to receive(:first).with(email: 'asd@fgh.net').and_return(nil) }
              let(:operation) { IfStepConditionalAfterRollbackOperation.new(logger: logger, should_run: should_run) }

              context 'when the condition is true' do
                let(:should_run) { true }

                it 'executes the after_rollback step' do
                  expect(logger).to receive(:log)

                  expect(operation).to fail_on(params)
                end
              end

              context 'when the condition is false' do
                let(:should_run) { false }

                it 'skips the after_rollback step' do
                  expect(DB).to_not receive(:after_rollback)
                  expect(logger).to_not receive(:log)

                  expect(operation).to fail_on(params)
                end
              end
            end

            context 'when both :if and :unless are provided' do
              class InvalidConditionalAfterRollbackOperation < LoggerOperation
                process do
                  transaction do
                    after_rollback :log_error, if: :is_good?, unless: :is_bad?
                  end
                end
              end

              let(:operation) { InvalidConditionalAfterRollbackOperation.new(logger: logger) }

              it 'raises an error' do
                expect { operation.call(params) }.to raise_error
                  .with_message('options :if and :unless are mutually exclusive')
              end
            end
          end

          context 'when providing a block and a step' do
            class AmbivalentAfterRollbackOperation < MyOperation
              process do
                transaction do
                  after_rollback :perform_db_action do
                    step :perform_other_db_action
                  end
                end
              end
            end

            let(:operation) { AmbivalentAfterRollbackOperation.new }

            it 'raises an error' do
              expect { operation.call(params) }.to raise_error
                .with_message('must provide either a step or a block but not both')
            end
          end

          context 'when not providing a block nor a step' do
            class InvalidAfterRollbackOperation < MyOperation
              process do
                transaction do
                  after_rollback
                end
              end
            end

            let(:operation) { InvalidAfterRollbackOperation.new }

            it 'raises an error' do
              expect { operation.call(params) }.to raise_error
                .with_message('must provide either a step or a block but not both')
            end
          end

          context 'when nesting operations with rollback callbacks' do
            class InnerFailingOperation < MyOperation
              context :notifier

              process do
                transaction do
                  after_rollback :notify_inner_rollback
                  step :fail_step
                end
                step :after_transaction_step
              end

              def fail_step(state)
                @notifier.inner_fail_step
                error(:inner_operation_failed)
              end

              def notify_inner_rollback(state)= @notifier.inner_rollback
              def after_transaction_step(state)= @notifier.inner_after_transaction
            end

            class OuterOperationWithRollback < MyOperation
              context :notifier

              process do
                transaction do
                  after_rollback :notify_outer_rollback
                  step :call_inner_operation
                  step :after_inner_call_step
                  step :fail_again
                end
                step :final_step
              end

              def call_inner_operation(state)
                state[:inner_result] = InnerFailingOperation.call({ notifier: @notifier }, state[:input])
                state
              end

              def fail_again(state)
                @notifier.outter_fail_step

                error(:outter_operation_failed) if state[:inner_result].failure?
              end

              def notify_outer_rollback(state)= @notifier.outer_rollback
              def after_inner_call_step(state)= @notifier.after_inner_call_step
              def final_step(state)= @notifier.final_step
            end

            let(:notifier) { spy }
            let(:operation) { OuterOperationWithRollback.new(notifier: notifier) }

            it 'executes rollback callbacks in the correct order when inner operation fails' do
              expect(notifier).to receive(:inner_fail_step)
              expect(notifier).to receive(:inner_rollback)
              expect(notifier).to receive(:after_inner_call_step)
              expect(notifier).to receive(:outter_fail_step)
              expect(notifier).to receive(:outer_rollback)

              # Verify calls that should NOT happen
              expect(notifier).to_not receive(:inner_after_transaction)
              expect(notifier).to_not receive(:final_step)

              expect(operation).to fail_on(zzz: :XXXXXXXXXXXXX)
                .with_type(:outter_operation_failed)
            end
          end
        end
      end

      let(:operation) { MyOperation.new }

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
          let(:opr_class) { MyOperation }
          subject(:opr_subclass) { Class.new(opr_class) }

          it "sets 'result_key', 'search_field', 'model_class' and 'model_not_found' from the superclass", :aggregate_failures do
            expect(opr_subclass.result_key).to eq(opr_class.result_key)
            expect(opr_subclass.search_field).to eq(opr_class.search_field)
            expect(opr_subclass.model_class).to eq(opr_class.model_class)
            expect(opr_subclass.model_not_found).to eq(opr_class.model_not_found)
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
        let(:other_model) { double(name: 'OtherModel') }
        let(:dataset) { double(model: other_model) }
        let(:object) { double }

        it "fetches an instance through 'model_class' into result key" do
          expect(MyModel).to receive(:first).with(email: key).and_return(object)

          expect(operation.fetch_model({input: {email: key}}).value[:my_model]).to eq(object)
        end

        context "when proving and external repository through 'from:'" do
          it "fetches an instance through 'model_class' and sets result key using an overrided search column, input key and 'from' model class" do
            expect(other_model).to receive(:first).with(pk: 'foo').and_return(object)
            expect(MyModel).to_not receive(:first)

            state  = { input: { myid: 'foo' } }
            result = operation
                       .fetch_model(state, from: other_model, using: :myid, search_by: :pk)
                       .value[:my_model]

            expect(result).to eq(object)
          end

          it "fetches an instance through 'model_class' and sets result key using an overrided search column, input key and 'from' dataset" do
            expect(dataset).to receive(:first).with(pk: 'foo').and_return(object)
            expect(MyModel).to_not receive(:first)

            state  = { input: { myid: 'foo' } }
            result = operation
                       .fetch_model(state, from: dataset, using: :myid, search_by: :pk)
                       .value[:my_model]

            expect(result).to eq(object)
          end
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

          result = operation.fetch_model({input: {email: key}})

          expect(result).to be_an(Result::Failure)
          expect(result.error).to be_an(Pathway::Error)
          expect(result.error.type).to eq(:not_found)
          expect(result.error.message).to eq('My model not found')
        end

        it 'returns an error without hitting the database when search key is nil', :aggregate_failures do
          expect(MyModel).to_not receive(:first)

          result = operation.fetch_model({input: {email: nil}})

          expect(result).to be_an(Result::Failure)
          expect(result.error).to be_an(Pathway::Error)
          expect(result.error.type).to eq(:not_found)
          expect(result.error.message).to eq('My model not found')
        end
      end

      describe '#call' do
        let(:operation)     { MyOperation.new(ctx) }
        let(:result)        { operation.call(email: 'an@email.com') }
        let(:fetched_model) { MyModel.new }

        context 'when the model is not present at the context' do
          let(:ctx) { {} }

          it "doesn't include the model's key on the operation's context" do
            expect(operation.context).to_not include(:my_model)
          end
          it 'fetchs the model from the DB' do
            expect(MyModel).to receive(:first).with(email: 'an@email.com').and_return(fetched_model)

            expect(result.value).to be(fetched_model)
          end
        end

        context 'when the model is already present in the context' do
          let(:existing_model) { MyModel.new }
          let(:ctx)            { { my_model: existing_model } }

          it "includes the model's key on the operation's context" do
            expect(operation.context).to include(my_model: existing_model)
          end
          it 'uses the model from the context and avoid querying the DB' do
            expect(MyModel).to_not receive(:first)

            expect(result.value).to be(existing_model)
          end

          context 'but :fetch_model step specifies overwrite: true' do
            class OwOperation < MyOperation
              process do
                step :fetch_model, overwrite: true
              end
            end

            let(:operation) { OwOperation.new(ctx) }

            it 'fetches the model from the DB anyway' do
              expect(MyModel).to receive(:first).with(email: 'an@email.com').and_return(fetched_model)

              expect(operation.context).to include(my_model: existing_model)
              expect(operation.my_model).to be(existing_model)
              expect(result.value).to be(fetched_model)
            end
          end
        end
      end

    end
  end
end

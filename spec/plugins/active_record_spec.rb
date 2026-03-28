# frozen_string_literal: true

require "spec_helper"
require "active_record"

module Pathway
  module Plugins
    describe "ActiveRecord" do
      ::ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
      ::ActiveRecord::Schema.verbose = false
      ::ActiveRecord::Schema.define do
        create_table :ar_my_models, force: true do |t|
          t.string :email
          t.string :name
          t.string :first_email
        end
      end

      class ARMyModel < ::ActiveRecord::Base; end

      def build_ar_model(attrs = {})
        defaults = { email: "asd@fgh.net", name: "default", first_email: "first@default.net" }
        ARMyModel.create!(defaults.merge(attrs))
      end

      class ARIdOperation < Operation
        plugin :active_record, model: ARMyModel
      end

      class ARMyOperation < Operation
        plugin :active_record

        context mailer: nil

        model ARMyModel, search_by: :email

        process do
          step :fetch_model
        end
      end

      class ARMailerOperation < ARMyOperation
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
          state[:army_model] = { model: state[:army_model] }
        end

        def send_emails(state)
          @mailer.send_emails(state[:army_model]) if @mailer
        end
      end

      class ARChainedOperation < ARMyOperation
        result_at :result

        process do
          transaction do
            set :chain_operation, to: :result
          end
        end

        def chain_operation(state)
          ARMailerOperation.call(context, state[:input])
        end
      end

      before do
        ARMyModel.delete_all
      end

      describe "DSL" do
        let(:params) { { email: "asd@fgh.net" } }
        let(:db) { ::ActiveRecord::Base }

        let(:mailer) { double.tap { |d| allow(d).to receive(:send_emails) } }
        let(:persisted_model) { build_ar_model(params) }

        describe "#transaction" do
          context "when providing a block" do
            let(:operation) { ARMailerOperation.new(mailer: mailer) }
            before { allow(db).to receive(:transaction).and_call_original }

            it "returns the result state provided by the inner transaction when successful" do
              expect(operation).to succeed_on(params).returning(model: persisted_model)
            end

            it "returns the error state provided by the inner transaction when there's a failure" do
              ARMyModel.delete_all

              expect(operation).to fail_on(params).with_type(:not_found)
            end

            context "a conditional," do
              class ARIfConditionalOperation < ARIdOperation
                context :should_run

                process do
                  transaction(if: :should_run?) do
                    step :fetch_model
                  end
                end

                private
                def should_run?(state)= state[:should_run]
              end

              let(:operation) { ARIfConditionalOperation.new(should_run: should_run) }
              let(:params) { { "id" => 77 } }

              context "when the condition is true" do
                let(:should_run) { true }

                it "executes the transaction" do
                  expect(db).to receive(:transaction).once.and_call_original
                  expect(operation).to succeed_on(params).returning(persisted_model)
                end
              end

              context "when the condition is false" do
                let(:should_run) { false }

                it "skips the transaction" do
                  expect(db).to_not receive(:transaction)

                  expect(operation).to succeed_on(params)
                end
              end
            end
          end

          context "when providing a step" do
            class ARFetchStepOperation < ARMyOperation
              process do
                transaction :fetch_model
              end
            end

            let(:operation) { ARFetchStepOperation.new(mailer: mailer) }
            before { allow(db).to receive(:transaction).and_call_original }

            it "returns the result state provided by the inner transaction when successful" do
              expect(operation).to succeed_on(params).returning(persisted_model)
            end

            it "returns the error state provided by the inner transaction when there's a failure" do
              ARMyModel.delete_all

              expect(operation).to fail_on(params).with_type(:not_found)
            end

            context "and conditional" do
              class ARUnlessConditionalOperation < ARIdOperation
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

              let(:operation) { ARUnlessConditionalOperation.new(should_skip: should_skip) }
              let(:params) { { "id" => 99 } }

              context "if the condition is true" do
                let(:should_skip) { false }

                it "executes the transaction" do
                  expect(db).to receive(:transaction).once.and_call_original
                  expect(operation).to succeed_on(params).returning(have_attributes(id: 99))
                end
              end

              context "if the condition is false" do
                let(:should_skip) { true }

                it "skips the transaction" do
                  expect(db).to_not receive(:transaction)

                  expect(operation).to succeed_on(params)
                end
              end
            end
          end

          context "when both an :if and :unless conditional" do
            class ARInvalidUseOfCondOperation < ARMyOperation
              process do
                transaction :perform_db_action, if: :is_good?, unless: :is_bad?
              end
            end

            let(:operation) { ARInvalidUseOfCondOperation.new }

            it "raises an error" do
              expect { operation.call(params) }.to raise_error
                                                     .with_message("options :if and :unless are mutually exclusive")
            end
          end

          context "when providing a block and a step" do
            class ARAmbivalentTransactOperation < ARMyOperation
              process do
                transaction :perform_db_action do
                  step :perform_other_db_action
                end
              end
            end

            let(:operation) { ARAmbivalentTransactOperation.new }

            it "raises an error" do
              expect { operation.call(params) }.to raise_error
                                                     .with_message("must provide either a step or a block but not both")
            end
          end

          context "when not providing a block nor a step" do
            class AREmptyTransacOperation < ARMyOperation
              process do
                transaction
              end
            end

            let(:operation) { AREmptyTransacOperation.new }

            it "raises an error" do
              expect { operation.call(params) }.to raise_error
                                                     .with_message("must provide either a step or a block but not both")
            end
          end
        end

        describe "#after_commit" do
          context "when providing a block" do
            let(:operation) { ARMailerOperation.new(mailer: mailer) }

            it "calls after_commit block when transaction is successful" do
              expect(db).to receive(:transaction).and_call_original
              expect(::ActiveRecord).to receive(:after_all_transactions_commit).and_call_original
              expect(mailer).to receive(:send_emails).with(persisted_model)

              expect(operation).to succeed_on(params)
            end

            it "does not call after_commit block when transaction fails" do
              expect(db).to receive(:transaction).and_call_original
              ARMyModel.delete_all
              expect(::ActiveRecord).to_not receive(:after_all_transactions_commit).and_call_original
              expect(mailer).to_not receive(:send_emails)

              expect(operation).to fail_on(params)
            end

            context "and the execution state is changed bellow the after_commit callback" do
              let(:operation) { ARChainedOperation.new(mailer: mailer) }

              it "ignores any state changes that took place following the after_commit block" do
                expect(mailer).to receive(:send_emails).with(persisted_model)

                expect(operation).to succeed_on(params).returning(model: persisted_model)
              end
            end
          end

          context "when providing a step" do
            class ARSendEmailStepOperation < ARMyOperation
              process do
                transaction do
                  step :fetch_model
                  after_commit :send_emails
                end
              end

              def send_emails(state)
                @mailer.send_emails(state[:army_model]) if @mailer
              end
            end

            let(:operation) { ARSendEmailStepOperation.new(mailer: mailer) }
            before { expect(db).to receive(:transaction).and_call_original }

            it "calls after_commit block when transaction is successful" do
              expect(::ActiveRecord).to receive(:after_all_transactions_commit).and_call_original
              expect(mailer).to receive(:send_emails).with(persisted_model)

              expect(operation).to succeed_on(params)
            end

            it "does not call after_commit block when transaction fails" do
              ARMyModel.delete_all
              expect(::ActiveRecord).to_not receive(:after_all_transactions_commit).and_call_original
              expect(mailer).to_not receive(:send_emails)

              expect(operation).to fail_on(params)
            end
          end

          context "with conditional execution" do
            context "using :if with and a block" do
              class ARIfConditionalAfterCommitOperation < ARMyOperation
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
                  @mailer.send_emails(state[:army_model]) if @mailer
                end

                private
                def should_run?(state) = state[:should_run]
              end

              let(:operation) { ARIfConditionalAfterCommitOperation.new(mailer: mailer, should_run: should_run) }
              let(:params) { { email: "asd@fgh.net" } }

              before { persisted_model }

              context "when the condition is true" do
                let(:should_run) { true }

                it "executes the after_commit block" do
                  expect(::ActiveRecord).to receive(:after_all_transactions_commit).and_call_original
                  expect(mailer).to receive(:send_emails).with(persisted_model)

                  expect(operation).to succeed_on(params)
                end
              end

              context "when the condition is false" do
                let(:should_run) { false }

                it "skips the after_commit block" do
                  expect(::ActiveRecord).to_not receive(:after_all_transactions_commit)
                  expect(mailer).to_not receive(:send_emails)

                  expect(operation).to succeed_on(params)
                end
              end
            end

            context "using :unless and a block" do
              class ARUnlessConditionalAfterCommitOperation < ARMyOperation
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
                  @mailer.send_emails(state[:army_model]) if @mailer
                end

                private
                def should_skip?(state) = state[:should_skip]
              end

              let(:operation) { ARUnlessConditionalAfterCommitOperation.new(mailer: mailer, should_skip: should_skip) }
              let(:params) { { email: "asd@fgh.net" } }

              before { persisted_model }

              context "when the condition is false" do
                let(:should_skip) { false }

                it "executes the after_commit block" do
                  expect(::ActiveRecord).to receive(:after_all_transactions_commit).and_call_original
                  expect(mailer).to receive(:send_emails).with(persisted_model)

                  expect(operation).to succeed_on(params)
                end
              end

              context "when the condition is true" do
                let(:should_skip) { true }

                it "skips the after_commit block" do
                  expect(::ActiveRecord).to_not receive(:after_all_transactions_commit)
                  expect(mailer).to_not receive(:send_emails)

                  expect(operation).to succeed_on(params)
                end
              end
            end

            context "using :if with step name" do
              class ARIfStepConditionalAfterCommitOperation < ARMyOperation
                context :should_run

                process do
                  transaction do
                    step :fetch_model
                    after_commit :send_emails, if: :should_run?
                  end
                end

                def send_emails(state)
                  @mailer.send_emails(state[:army_model]) if @mailer
                end

                private
                def should_run?(state) = state[:should_run]
              end

              before { persisted_model }
              let(:operation) { ARIfStepConditionalAfterCommitOperation.new(mailer: mailer, should_run: should_run) }

              context "when the condition is true" do
                let(:should_run) { true }

                it "executes the after_commit step" do
                  expect(::ActiveRecord).to receive(:after_all_transactions_commit).and_call_original
                  expect(mailer).to receive(:send_emails).with(persisted_model)

                  expect(operation).to succeed_on(params)
                end
              end

              context "when the condition is false" do
                let(:should_run) { false }

                it "skips the after_commit step" do
                  expect(::ActiveRecord).to_not receive(:after_all_transactions_commit)
                  expect(mailer).to_not receive(:send_emails)

                  expect(operation).to succeed_on(params)
                end
              end
            end

            context "when both :if and :unless are provided" do
              class ARInvalidConditionalAfterCommitOperation < ARMyOperation
                process do
                  transaction do
                    after_commit :send_emails, if: :is_good?, unless: :is_bad?
                  end
                end
              end

              let(:operation) { ARInvalidConditionalAfterCommitOperation.new }

              it "raises an error" do
                expect { operation.call(params) }.to raise_error
                                                       .with_message("options :if and :unless are mutually exclusive")
              end
            end
          end

          context "when providing a block and a step" do
            class ARAmbivalentAfterCommitOperation < ARMyOperation
              process do
                transaction do
                  after_commit :perform_db_action do
                    step :perform_other_db_action
                  end
                end
              end
            end

            let(:operation) { ARAmbivalentAfterCommitOperation.new }

            it "raises an error" do
              expect { operation.call(params) }.to raise_error
                                                     .with_message("must provide either a step or a block but not both")
            end
          end

          context "when not providing a block nor a step" do
            class ARInvalidAfterCommitOperation < ARMyOperation
              process do
                transaction do
                  after_commit
                end
              end
            end

            let(:operation) { ARInvalidAfterCommitOperation.new }

            it "raises an error" do
              expect { operation.call(params) }.to raise_error
                                                     .with_message("must provide either a step or a block but not both")
            end
          end
        end

        describe "#after_rollback" do
          class ARLoggerOperation < ARMyOperation
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

          context "when providing a block" do
            class ARRollbackWithBlockOperation < ARLoggerOperation
              process do
                transaction do
                  after_rollback do
                    step :log_error
                  end

                  step :fetch_model
                end
              end
            end

            let(:operation) { ARRollbackWithBlockOperation.new(logger: logger) }
            before { expect(db).to receive(:transaction).and_call_original }

            it "calls after_rollback block when transaction fails" do
              ARMyModel.delete_all
              expect(logger).to receive(:log)

              expect(operation).to fail_on(params)
            end

            it "does not call after_rollback block when transaction succeeds" do
              build_ar_model(params)
              expect(logger).to_not receive(:log)

              expect(operation).to succeed_on(params)
            end
          end

          context "when providing a step" do
            class ARRollbackStepOperation < ARLoggerOperation
              process do
                transaction do
                  after_rollback :log_error
                  step :fetch_model
                end
              end
            end

            let(:operation) { ARRollbackStepOperation.new(logger: logger) }
            before { expect(db).to receive(:transaction).and_call_original }

            it "calls after_rollback step when transaction fails" do
              ARMyModel.delete_all
              expect(logger).to receive(:log)

              expect(operation).to fail_on(params)
            end

            it "does not call after_rollback step when transaction succeeds" do
              build_ar_model(params)
              expect(logger).to_not receive(:log)

              expect(operation).to succeed_on(params)
            end
          end

          context "with conditional execution" do
            context "using :if with a block" do
              class ARIfConditionalAfterRollbackOperation < ARLoggerOperation
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

              let(:operation) { ARIfConditionalAfterRollbackOperation.new(logger: logger, should_run: should_run) }
              let(:params) { { email: "asd@fgh.net" } }

              before { ARMyModel.delete_all }

              context "when the condition is true" do
                let(:should_run) { true }

                it "executes the after_rollback block" do
                  expect(logger).to receive(:log)

                  expect(operation).to fail_on(params)
                end
              end

              context "when the condition is false" do
                let(:should_run) { false }

                it "skips the after_rollback block" do
                  expect(db).to_not receive(:after_rollback)
                  expect(logger).to_not receive(:log)

                  expect(operation).to fail_on(params)
                end
              end
            end

            context "using :unless with a block" do
              class ARUnlessConditionalAfterRollbackOperation < ARLoggerOperation
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

              let(:operation) { ARUnlessConditionalAfterRollbackOperation.new(logger: logger, should_skip: should_skip) }
              let(:params) { { email: "asd@fgh.net" } }

              before { ARMyModel.delete_all }

              context "when the condition is false" do
                let(:should_skip) { false }

                it "executes the after_rollback block" do
                  expect(logger).to receive(:log)

                  expect(operation).to fail_on(params)
                end
              end

              context "when the condition is true" do
                let(:should_skip) { true }

                it "skips the after_rollback block" do
                  expect(db).to_not receive(:after_rollback)
                  expect(logger).to_not receive(:log)

                  expect(operation).to fail_on(params)
                end
              end
            end

            context "using :if with step name" do
              class ARIfStepConditionalAfterRollbackOperation < ARLoggerOperation
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

              before { ARMyModel.delete_all }
              let(:operation) { ARIfStepConditionalAfterRollbackOperation.new(logger: logger, should_run: should_run) }

              context "when the condition is true" do
                let(:should_run) { true }

                it "executes the after_rollback step" do
                  expect(logger).to receive(:log)

                  expect(operation).to fail_on(params)
                end
              end

              context "when the condition is false" do
                let(:should_run) { false }

                it "skips the after_rollback step" do
                  expect(db).to_not receive(:after_rollback)
                  expect(logger).to_not receive(:log)

                  expect(operation).to fail_on(params)
                end
              end
            end

            context "when both :if and :unless are provided" do
              class ARInvalidConditionalAfterRollbackOperation < ARLoggerOperation
                process do
                  transaction do
                    after_rollback :log_error, if: :is_good?, unless: :is_bad?
                  end
                end
              end

              let(:operation) { ARInvalidConditionalAfterRollbackOperation.new(logger: logger) }

              it "raises an error" do
                expect { operation.call(params) }.to raise_error
                                                       .with_message("options :if and :unless are mutually exclusive")
              end
            end
          end

          context "when providing a block and a step" do
            class ARAmbivalentAfterRollbackOperation < ARMyOperation
              process do
                transaction do
                  after_rollback :perform_db_action do
                    step :perform_other_db_action
                  end
                end
              end
            end

            let(:operation) { ARAmbivalentAfterRollbackOperation.new }

            it "raises an error" do
              expect { operation.call(params) }.to raise_error
                                                     .with_message("must provide either a step or a block but not both")
            end
          end

          context "when not providing a block nor a step" do
            class ARInvalidAfterRollbackOperation < ARMyOperation
              process do
                transaction do
                  after_rollback
                end
              end
            end

            let(:operation) { ARInvalidAfterRollbackOperation.new }

            it "raises an error" do
              expect { operation.call(params) }.to raise_error
                                                     .with_message("must provide either a step or a block but not both")
            end
          end

          context "when nesting operations with rollback callbacks" do
            class ARInnerFailingOperation < ARMyOperation
              context :notifier

              process do
                transaction do
                  after_rollback :notify_inner_rollback
                  step :fail_step
                end
                step :after_transaction_step
              end

              def fail_step(_state)
                @notifier.inner_fail_step
                error(:inner_operation_failed)
              end

              def notify_inner_rollback(_state)= @notifier.inner_rollback
              def after_transaction_step(_state)= @notifier.inner_after_transaction
            end

            class AROuterOperationWithRollback < ARMyOperation
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
                state[:inner_result] = ARInnerFailingOperation.call({ notifier: @notifier }, state[:input])
                state
              end

              def fail_again(state)
                @notifier.outter_fail_step

                error(:outter_operation_failed) if state[:inner_result].failure?
              end

              def notify_outer_rollback(_state)= @notifier.outer_rollback
              def after_inner_call_step(_state)= @notifier.after_inner_call_step
              def final_step(_state)= @notifier.final_step
            end

            let(:notifier) { spy }
            let(:operation) { AROuterOperationWithRollback.new(notifier: notifier) }

            it "executes rollback callbacks in the correct order when inner operation fails" do
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

      let(:operation) { ARMyOperation.new }

      describe ".model" do
        it "sets the 'result_key' using the model class name" do
          expect(operation.result_key).to eq(:army_model)
        end

        it "sets the 'model_class' using the first parameter" do
          expect(operation.model_class).to eq(ARMyModel)
        end

        context "when a :search_field option is specified" do
          it "sets the 'search_field' with the provided value" do
            expect(operation.search_field).to eq(:email)
          end
        end

        context "when no :search_field option is specified" do
          let(:operation) { ARIdOperation.new }

          it "sets the 'search_field' from the model's id" do
            expect(operation.search_field).to eq("id")
          end
        end

        context "when the operation is inherited" do
          let(:opr_class) { ARMyOperation }
          subject(:opr_subclass) { Class.new(opr_class) }

          it "sets 'result_key', 'search_field', 'model_class' and 'model_not_found' from the superclass", :aggregate_failures do
            expect(opr_subclass.result_key).to eq(opr_class.result_key)
            expect(opr_subclass.search_field).to eq(opr_class.search_field)
            expect(opr_subclass.model_class).to eq(opr_class.model_class)
            expect(opr_subclass.model_not_found).to eq(opr_class.model_not_found)
          end
        end
      end

      let(:key)    { "some@email.com" }
      let(:params) { { foo: 3, bar: 4} }

      describe "#find_model_with" do
        it "queries the db through the 'model_class'" do
          build_ar_model(email: key)

          operation.find_model_with(key)
        end
      end

      describe "#fetch_model" do
        let(:other_model) { double(name: "OtherModel") }
        let(:relation) { double(klass: other_model) }
        let(:object) { double }

        it "fetches an instance through 'model_class' into result key" do
          object = build_ar_model(email: key)

          expect(operation.fetch_model({input: {email: key}}).value[:army_model]).to eq(object)
        end

        context "when proving and external repository through 'from:'" do
          it "fetches an instance through 'model_class' and sets result key using an overrided search column, input key and 'from' model class" do
            expect(other_model).to receive(:find_by).with(id: "foo").and_return(object)
            ARMyModel.delete_all

            state  = { input: { myid: "foo" } }
            result = operation
                       .fetch_model(state, from: other_model, using: :myid, search_by: :id)
                       .value[:army_model]

            expect(result).to eq(object)
          end

          it "fetches an instance through 'model_class' and sets result key using an overrided search column, input key and 'from' relation" do
            expect(relation).to receive(:find_by).with(id: "foo").and_return(object)
            ARMyModel.delete_all

            state  = { input: { myid: "foo" } }
            result = operation
                       .fetch_model(state, from: relation, using: :myid, search_by: :id)
                       .value[:army_model]

            expect(result).to eq(object)
          end
        end

        it "fetches an instance through 'model_class' and sets result key using an overrided search column and input key with only :search_by is provided" do
          object = build_ar_model(name: "foobar")

          state  = { input: { email: "other@email.com", name: "foobar" } }
          result = operation
                     .fetch_model(state, search_by: :name)
                     .value[:army_model]

          expect(result).to eq(object)
        end

        it "fetches an instance through 'model_class' and sets result key using an overrided input key with but not search column when only :using is provided" do
          object = build_ar_model(email: "foobar@mail.com")

          state  = { input: { email: "other@email.com", first_email: "foobar@mail.com" } }
          result = operation
                     .fetch_model(state, using: :first_email)
                     .value[:army_model]

          expect(result).to eq(object)
        end

        it "returns an error when no instance is found", :aggregate_failures do
          ARMyModel.delete_all

          result = operation.fetch_model({input: {email: key}})

          expect(result).to be_an(Result::Failure)
          expect(result.error).to be_an(Pathway::Error)
          expect(result.error.type).to eq(:not_found)
          expect(result.error.message).to eq("Army model not found")
        end

        it "returns an error without hitting the database when search key is nil", :aggregate_failures do
          ARMyModel.delete_all

          result = operation.fetch_model({input: {email: nil}})

          expect(result).to be_an(Result::Failure)
          expect(result.error).to be_an(Pathway::Error)
          expect(result.error.type).to eq(:not_found)
          expect(result.error.message).to eq("Army model not found")
        end
      end

      describe "#call" do
        let(:operation)     { ARMyOperation.new(ctx) }
        let(:result)        { operation.call(email: "an@email.com") }

        context "when the model is not present at the context" do
          let(:ctx) { {} }

          it "doesn't include the model's key on the operation's context" do
            expect(operation.context).to_not include(:army_model)
          end
          it "fetchs the model from the AR_DB" do
            fetched_model = build_ar_model(email: "an@email.com")

            expect(result.value).to eq(fetched_model)
          end
        end

        context "when the model is already present in the context" do
          let(:existing_model) { double }
          let(:ctx)            { { army_model: existing_model } }

          it "includes the model's key on the operation's context" do
            expect(operation.context).to include(army_model: existing_model)
          end
          it "uses the model from the context and avoid querying the AR_DB" do
            ARMyModel.delete_all

            expect(result.value).to eq(existing_model)
          end

          context "but :fetch_model step specifies overwrite: true" do
            class AROwOperation < ARMyOperation
              process do
                step :fetch_model, overwrite: true
              end
            end

            let(:operation) { AROwOperation.new(ctx) }

            it "fetches the model from the AR_DB anyway" do
              fetched_model = build_ar_model(email: "an@email.com")

              expect(operation.context).to include(army_model: existing_model)
              expect(operation.army_model).to eq(existing_model)
              expect(result.value).to eq(fetched_model)
            end
          end
        end
      end

    end
  end
end

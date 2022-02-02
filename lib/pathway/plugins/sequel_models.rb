# frozen_string_literal: true

require 'sequel/model'

module Pathway
  module Plugins
    module SequelModels
      module DSLMethods
        def transaction(step_name = nil, &bl)
          fail 'must provide a step or a block but not both' if !step_name.nil? == block_given?

          if step_name
            transaction { step step_name }
          else
            around(-> steps, _ {
              db.transaction(savepoint: true) do
                raise Sequel::Rollback if steps.call.failure?
              end
            }, &bl)
          end
        end

        def after_commit(step_name = nil, &bl)
          fail 'must provide a step or a block but not both' if !step_name.nil? == block_given?

          if step_name
            after_commit { step step_name }
          else
            around(-> steps, state {
              dsl = self.class::DSL.new(State.new(self, state.to_h.dup), self)

              db.after_commit do
                steps.call(dsl)
              end
            }, &bl)
          end
        end
      end

      module ClassMethods
        attr_accessor :model_class, :search_field, :model_not_found

        def model(model_class, search_by: model_class.primary_key, set_result_key: true, set_context_param: true, error_message: nil)
          self.model_class      = model_class
          self.search_field     = search_by
          self.result_key       = Inflector.underscore(Inflector.demodulize(model_class.name)).to_sym if set_result_key
          self.model_not_found  = error_message || "#{Inflector.humanize(Inflector.underscore(Inflector.demodulize(model_class.name)))} not found".freeze

          self.context(result_key => Contextualizer::OPTIONAL) if set_result_key && set_context_param
        end

        def inherited(subclass)
          super
          subclass.model_class     = model_class
          subclass.search_field    = search_field
          subclass.model_not_found = model_not_found
        end
      end

      module InstanceMethods
        extend Forwardable
        delegate %i[model_class search_field model_not_found] => 'self.class'
        delegate :db => :model_class

        def fetch_model(state, from: model_class, search_by: search_field, using: search_by, to: result_key, overwrite: false, error_message: nil, **)
          error_message ||= if (from == model_class)
                              model_not_found
                            elsif from.respond_to?(:name) || from.respond_to?(:model)
                              from_name = (from.respond_to?(:name) ? from : from.model).name
                              Inflector.humanize(Inflector.underscore(Inflector.demodulize(from_name))) + ' not found'
                            end

          if state[to].nil? || overwrite
            wrap_if_present(state[:input][using], message: error_message)
              .then { |key| find_model_with(key, from, search_by, error_message) }
              .then { |model| state.update(to => model) }
          else
            state
          end
        end

        def find_model_with(key, dataset = model_class, column = search_field, error_message = nil)
          wrap_if_present(dataset.first(column => key), message: error_message)
        end
      end

      def self.apply(operation, model: nil, **args)
        operation.model(model, **args) if model
      end
    end
  end
end

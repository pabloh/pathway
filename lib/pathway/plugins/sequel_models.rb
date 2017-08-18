require 'sequel/model'

module Pathway
  module Plugins
    module SequelModels
      module DSLMethods
        def transaction(&bl)
          sequence(-> seq, _ {
            db.transaction(savepoint: true) do
              raise Sequel::Rollback if seq.call.failure?
            end
          }, &bl)
        end

        def after_commit(&bl)
          sequence(-> seq, _ {
            db.after_commit do
              seq.call
            end
          }, &bl)
        end
      end

      module InstanceMethods
        module Finder
          def self.[](model_class, by: :id)
            Module.new do
              include InstanceMethods

              define_singleton_method :included do |klass|
                klass.class_eval do
                  result_at Inflecto.underscore(model_class.name.split('::').last).to_sym

                  define_method(:model_class) { model_class }
                  define_method(:field)       { by }
                  define_method(:db)          { model_class.db }
                end
              end
            end
          end
        end

        extend Forwardable
        delegate %i[model_class db field] => 'self.class'

        def fetch_model(state, from: model_class, key: field, column: field, overwrite: false)
          if state[result_key].nil? || overwrite
            find_model_with(state[:input][key], from, column)
              .then { |model| state.update(result_key => model) }
          else
            state
          end
        end

        def build_model_with(params)
          wrap(model_class.new(params))
        end

        def find_model_with(key, dataset = model_class, column = field)
          wrap_if_present(dataset.first(column => key))
        end
      end
    end
  end
end

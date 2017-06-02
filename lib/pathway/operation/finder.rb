module Pathway
  class Operation
    module Finder
      def self.[](model_class, by: :id)
        Module.new do
          include InstanceMethods

          define_singleton_method :included do |klass|
            klass.class_eval do
              result_at model_class.name.split('::').last.underscore.to_sym

              define_method(:model_class) { model_class }
              define_method(:field)       { by }
              delegate :db => :model_class
            end
          end
        end
      end

      module InstanceMethods
        extend Forwardable
        delegate %i[model_class db field] => 'self.class'

        def fetch_model(state)
          fetch_model_with(state[:input])
            .then { |model| state.update(result_key => model) }
        end

        def fetch_model_with(params)
          wrap_if_present(find_model_with(params[field]))
        end

        def build_model_with(params)
          wrap(model_class.new(params))
        end

        def find_model_with(key)
          model_class.first(field => key)
        end

        def wrap_transaction(use_db = db)
          result = nil
          use_db.transaction(savepoint: true) do
            result = yield
            raise Sequel::Rollback if result.failure?
          end
          result
        end
      end
    end
  end
end

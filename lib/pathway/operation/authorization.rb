module Pathway
  class Operation
    module Authorization
      module ClassMethods
        def authorization(&block)
          define_method(:authorized?, &block)
        end
      end

      def self.included(klass)
        klass.extend ClassMethods
      end

      def authorize(state)
        authorize_with(state.result).then { state }
      end

      def authorize_with(*objs)
        objs = objs.first if objs.size <= 1
        authorized?(*objs) ? wrap(objs) : error(:forbidden)
      end

      def authorized?(*_)
        true
      end
    end
  end
end

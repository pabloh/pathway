module Pathway
  module Plugins
    module Authorization
      module ClassMethods
        def authorization(&block)
          define_method(:authorized?, &block)
        end
      end

      module InstanceMethods
        def authorize(state, using: nil)
          authorize_with(state[using || result_key]).then { state }
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
end

# frozen_string_literal: true

module Pathway
  module Plugins
    module SimpleAuth
      module ClassMethods
        def authorization(&block)
          define_method(:authorized?) do |*args|
            instance_exec(*args, &block)
          end
        end
      end

      module InstanceMethods
        def authorize(state, using: nil, **)
          auth_state = if using.is_a?(Array)
                         authorize_with(*state.values_at(*using))
                       else
                         authorize_with(state[using || result_key])
                       end

          auth_state.then { state }
        end

        def authorize_with(*objs)
          authorized?(*objs) ? wrap(objs) : error(:forbidden)
        end

        def authorized?(*)
          true
        end
      end
    end
  end
end

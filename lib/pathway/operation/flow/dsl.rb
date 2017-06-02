module Pathway
  class Operation
    module Flow
      class DSL
        def initialize(operation, input)
          @operation = operation
          @state     = State.new(operation, input: input)
          @result    = wrap(@state)
        end

        def run(&bl)
          instance_eval(&bl)
        end

        # Execute step and preserve the former state
        def step(callable = nil, &bl)
          bl = _callable(callable, &bl)

          and_then do |state|
            wrap(bl.call(state)).then { state }
          end
        end

        # Execute step and modify the former state setting the key
        def set(to = nil, callable = nil, &bl)
          to, callable = @operation.result_key, to unless block_given? || callable
          bl = _callable(callable, &bl)

          and_then do |state|
            wrap(bl.call(state))
              .then { |value| state.update(to => value) }
          end
        end

        # Execute step and replace the current state completely
        def and_then(callable = nil, &bl)
          bl = _callable(callable, &bl)
          @result = @result.then(bl)
        end

        private

        def wrap(obj)
          Result.result(obj)
        end

        def _callable(callable = nil, &bl)
          fail "next step not provided" unless callable || bl

          if block_given?
            -> arg { @operation.instance_exec(arg, &bl) }
          elsif callable.is_a?(Symbol)
            -> arg { @operation.send(callable, arg) }
          else
            callable
          end
        end
      end
    end
  end
end

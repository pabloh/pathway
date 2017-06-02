module Pathway
  class Operation
    module Flow
      class State
        extend Forwardable

        def initialize(operation, values = {})
          @hash = operation.context.merge(values)
          @result_key = operation.result_key
        end

        delegate %i([] []= fetch store include?) => :@hash

        def update(kargs)
          @hash.update(kargs)
          self
        end

        def result
          @hash[@result_key]
        end

        def to_hash
          @hash
        end

        alias :to_h :to_hash
      end
    end
  end
end

# frozen_string_literal: true

module Pathway
  module Plugins
    module AutoDeconstructState
      module DSLMethods
        private

        def _callable(callable)
          if callable.is_a?(Symbol) && @operation.respond_to?(callable, true) &&
            @operation.method(callable).parameters.all? { _1 in [:key|:keyreq|:keyrest|:block,*] }

            -> state { @operation.send(callable, **state) }
          else
            super
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Pathway
  module Plugins
    module AutoDeconstructState
      module ClassMethods
        attr_accessor :auto_deconstruct_state_on

        def inherited(subclass)
          super
          subclass.auto_deconstruct_state_on = auto_deconstruct_state_on
        end
      end

      module InstanceMethods
        extend Forwardable
        delegate :auto_deconstruct_state_on => 'self.class'
      end

      module DSLMethods
        private

        def _callable(callable, &block)
          next_step = super

          if callable.is_a?(Symbol) &&
            (block_given? && @operation.auto_deconstruct_state_on.member?(:block) && _can_deconstruct?(block) ||
            @operation.auto_deconstruct_state_on.member?(:method) && @operation.respond_to?(callable, true) &&
              _can_deconstruct?(@operation.method(callable)))

            ->(state, **kw) { next_step.call(**state, **kw) }
          else
            next_step
          end
        end

        def _can_deconstruct?(cb)= cb.parameters.all? { _1 in [:key|:keyreq|:keyrest|:block, *] }
      end

      OPTIONS = %i[all method block].freeze

      def self.apply(operation, on: :all)
        operation.auto_deconstruct_state_on= :all == on ? OPTIONS - [:all] : Array(on)
      end
    end
  end
end

require 'pathway/operation/flow/dsl'
require 'pathway/operation/flow/state'

module Pathway
  class Operation
    module Flow
      module ClassMethods
        attr_accessor :result_key

        def process(&bl)
          define_method(:call) do |input|
            DSL.new(self, input).run(&bl)
              .then { |state| state[result_key] }
          end
        end

        alias :result_at :result_key=

        def inherited(subclass)
          super
          subclass.result_key = result_key
        end
      end

      extend Forwardable

      delegate :result_key => 'self.class'

      def self.included(klass)
        klass.extend ClassMethods
        klass.result_key = :value
      end

      def sequence(&bl)
      end
    end
  end
end

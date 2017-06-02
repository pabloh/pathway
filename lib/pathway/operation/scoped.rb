require 'pathway/initializer'

module Pathway
  class Operation
    module Scoped
      module ClassMethods
        def scope(*attrs)
          include Initializer[*attrs]
        end
      end

      def self.included(klass)
        klass.extend ClassMethods
      end

      def initialize(*)
      end

      def context
        @context || {}
      end
    end
  end
end

require 'pathway/initializer'

module Pathway
  class Operation
    module Scoped
      module ClassMethods
        def scope(*attrs)
          include Initializer[*attrs]
        end
      end

      module InstanceMethods
        def initialize(*)
        end

        def context
          @context || {}
        end
      end

      def self.included(klass)
        klass.extend ClassMethods
        klass.include InstanceMethods
      end
    end
  end
end

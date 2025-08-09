# frozen_string_literal: true

require "dry/validation"

module Pathway
  module Plugins
    module DryValidation
      module ClassMethods
        attr_reader :contract_class, :contract_options
        attr_accessor :auto_wire

        def contract(base = nil, &)
          if block_given?
            base ||= _base_contract
            self.contract_class = Class.new(base, &)
          elsif base
            self.contract_class = base
          else
            raise ArgumentError, "Either a contract class or a block must be provided"
          end
        end

        def params(...)
          contract { params(...) }
        end

        def contract_class= klass
          @contract_class   = klass
          @contract_options = (klass.dry_initializer.options - Dry::Validation::Contract.dry_initializer.options).map(&:target)
          @builded_contract = @contract_options.empty? && klass.schema ? klass.new : nil
        end

        def build_contract(**)
          @builded_contract || contract_class.new(**)
        end

        def inherited(subclass)
          super
          subclass.auto_wire      = auto_wire
          subclass.contract_class = contract_class
        end

        private

        def _base_contract
          superclass.respond_to?(:contract_class) ? superclass.contract_class : Dry::Validation::Contract
        end
      end

      module InstanceMethods
        extend Forwardable

        delegate %i[build_contract contract_options auto_wire] => "self.class"
        alias_method :contract, :build_contract

        def validate(state, with: nil)
          if auto_wire && contract_options.any?
            with ||= contract_options.zip(contract_options).to_h
          end
          opts = Hash(with).map { |to, from| [to, state[from]] }.to_h
          validate_with(state[:input], **opts)
            .then { |params| state.update(params:) }
        end

        def validate_with(input, **)
          result = contract(**).call(input)

          result.success? ? wrap(result.values.to_h) : error(:validation, details: result.errors.to_h)
        end
      end

      def self.apply(operation, auto_wire: false)
        operation.auto_wire      = auto_wire
        operation.contract_class = Dry::Validation::Contract
      end
    end
  end
end

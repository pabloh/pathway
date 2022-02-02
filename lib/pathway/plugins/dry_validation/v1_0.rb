# frozen_string_literal: true

module Pathway
  module Plugins
    module DryValidation
      module V1_0
        module ClassMethods
          attr_reader :contract_class, :contract_options
          attr_accessor :auto_wire_options

          def contract(base = nil, &block)
            if block_given?
              base ||= _base_contract
              self.contract_class = Class.new(base, &block)
            elsif base
              self.contract_class = base
            else
              raise ArgumentError, 'Either a contract class or a block must be provided'
            end
          end

          def params(*args, &block)
            contract { params(*args, &block) }
          end

          def contract_class= klass
            @contract_class = klass
            @contract_options = (klass.dry_initializer.options - Dry::Validation::Contract.dry_initializer.options).map(&:target)
            @builded_contract = @contract_options.empty? && klass.schema ? klass.new : nil
          end

          def build_contract(opts = {})
            @builded_contract || contract_class.new(opts)
          end

          def inherited(subclass)
            super
            subclass.contract_class = contract_class
            subclass.auto_wire_options = auto_wire_options
          end

          private

          def _base_contract
            superclass.respond_to?(:contract_class) ? superclass.contract_class : Dry::Validation::Contract
          end
        end

        module InstanceMethods
          extend Forwardable

          delegate %i[build_contract contract_options auto_wire_options] => 'self.class'
          alias :contract :build_contract

          def validate(state, with: nil, **)
            if auto_wire_options && contract_options.any?
              with ||= contract_options.zip(contract_options).to_h
            end
            opts = Hash(with).map { |to, from| [to, state[from]] }.to_h
            validate_with(state[:input], opts)
              .then { |params| state.update(params: params) }
          end

          def validate_with(input, opts = {})
            result = contract(opts).call(input)

            result.success? ? wrap(result.values.to_h) : error(:validation, details: result.errors.to_h)
          end
        end

        def self.apply(operation, auto_wire_options: false)
          operation.contract_class = Dry::Validation::Contract
          operation.auto_wire_options = auto_wire_options
        end
      end
    end
  end
end

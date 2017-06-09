require 'forwardable'
require 'inflecto'
require 'pathway/version'
require 'pathway/initializer'
require 'pathway/result'
require 'pathway/error'

module Pathway
  class Operation
    def self.plugin(name)
      require "pathway/plugins/#{Inflecto.underscore(name)}" if name.is_a?(Symbol)

      plugin = name.is_a?(Module) ? name : Plugins.const_get(Inflecto.camelize(name))

      self.extend plugin::ClassMethods if plugin.const_defined? :ClassMethods
      self.include plugin::InstanceMethods if plugin.const_defined? :InstanceMethods
      plugin.apply(self) if plugin.respond_to?(:apply)
    end
  end

  module Plugins
    module Scope
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
    end

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

      module InstanceMethods
        extend Forwardable

        def result_key
          self.class.result_key
        end

        def call(*)
          fail "must implement at subclass"
        end

        delegate %i[result success failure] => Result

        alias :wrap :result

        def error(type, message: nil, details: nil)
          failure Error.new(type: type, message: message, details: details)
        end

        def wrap_if_present(value, type: :not_found, message: nil, details: [])
          value.nil? ? error(type, message: message, details: details) : success(value)
        end
      end

      def self.apply(klass)
        klass.result_key = :value
      end

      class DSL
        def initialize(operation, input_or_result)
          @result = if input_or_result.is_a?(Result)
                     input_or_result
                    else
                     wrap(State.new(operation, input: input_or_result))
                    end
          @operation = operation
        end

        def run(&bl)
          instance_eval(&bl)
          @result
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

        def sequence(with_seq, &bl)
          @result.then do |state|
            seq = -> { DSL.new(@operation, @result).run(&bl) }
            @operation.instance_exec(seq, state, &with_seq)
          end
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

  Operation.plugin Plugins::Scope
  Operation.plugin Plugins::Flow
end

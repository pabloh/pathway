# frozen_string_literal: true

require "forwardable"
require "dry/inflector"
require "contextualizer"
require "pathway/version"
require "pathway/result"

module Pathway
  Inflector = Dry::Inflector.new
  class Operation
    class << self
      def plugin(name,...)
        require "pathway/plugins/#{Inflector.underscore(name)}" if name.is_a?(Symbol)

        plugin = name.is_a?(Module) ? name : Plugins.const_get(Inflector.camelize(name))

        self.extend plugin::ClassMethods if plugin.const_defined? :ClassMethods
        self.include plugin::InstanceMethods if plugin.const_defined? :InstanceMethods
        self::DSL.include plugin::DSLMethods if plugin.const_defined? :DSLMethods

        plugin.apply(self,...) if plugin.respond_to?(:apply)
      end

      def inherited(subclass)
        super
        subclass.const_set :DSL, Class.new(self::DSL)
      end
    end

    class DSL
    end
  end

  class Error
    attr_reader :type, :message, :details
    singleton_class.send :attr_accessor, :default_messages

    @default_messages = {}

    def initialize(type:, message: nil, details: nil)
      @type    = type.to_sym
      @message = message || default_message_for(type)
      @details = details || {}
    end

    def deconstruct = [type, message, details]
    def deconstruct_keys(_) = { type:, message:, details: }

    private

    def default_message_for(type)
      self.class.default_messages[type] || Inflector.humanize(type)
    end
  end

  class State
    extend Forwardable
    delegate %i([] []= fetch store include? values_at deconstruct_keys) => :@hash

    def initialize(operation, values = {})
      @hash = operation.context.merge(values)
      @result_key = operation.result_key
    end

    def update(kargs)
      @hash.update(kargs)
      self
    end

    def result = @hash[@result_key]
    def to_hash = @hash

    def use(&bl)
      raise ArgumentError, "a block must be provided" if !block_given?
      if bl.parameters in [*, [:rest|:keyrest,], *]
        raise ArgumentError, "rest arguments are not supported"
      end

      keys = bl.parameters.select { _1 in :key|:keyreq, }.map(&:last)
      names = bl.parameters.select { _1 in :req|:opt, }.map(&:last)

      if keys.any? && names.any?
        raise ArgumentError, "cannot mix positional and keyword arguments"
      elsif keys.any?
        bl.call(**to_hash.slice(*keys))
      else
        bl.call(*to_hash.values_at(*names))
      end
    end

    alias_method :to_h, :to_hash
    alias_method :u, :use
    alias_method :unwrap, :use
  end

  module Plugins
    module Base
      module ClassMethods
        attr_accessor :result_key

        alias_method :result_at, :result_key=

        def process(&steps)
          define_method(:call) do |input|
            _dsl_for(input:)
               .run(&steps)
               .then(&:result)
          end
        end

        def call(ctx,...) = new(ctx).call(...)

        def inherited(subclass)
          super
          subclass.result_key = result_key
        end
      end

      module InstanceMethods
        extend Forwardable

        delegate :result_key => "self.class"
        delegate %i[result success failure] => Result

        alias_method :wrap, :result

        def call(*) = raise "must implement at subclass"

        def error(type, message: nil, details: nil)
          failure(Error.new(type:, message:, details:))
        end

        def wrap_if_present(value, type: :not_found, message: nil, details: {})
          value.nil? ? error(type, message:, details:) : success(value)
        end

        private

        def _dsl_for(vals) = self.class::DSL.new(State.new(self, vals), self)
      end

      def self.apply(klass)
        klass.extend Contextualizer
        klass.result_key = :value
      end

      module DSLMethods
        def initialize(state, operation)
          @result, @operation = wrap(state), operation
        end

        def run(&steps)
          instance_eval(&steps)
          @result
        end

        # Execute step and preserve the former state
        def step(callable,...)
          bl = _callable(callable)
          @result = @result.tee { |state| bl.call(state,...) }
        end

        # Execute step and modify the former state setting the key
        def set(callable, *args, to: @operation.result_key, **kwargs, &bl)
          bl = _callable(callable)

          @result = @result.then do |state|
            wrap(bl.call(state, *args, **kwargs, &bl))
              .then { |value| state.update(to => value) }
          end
        end

        # Execute step and replace the current state completely
        def map(callable,...)
          bl = _callable(callable)
          @result = @result.then { |state| bl.call(state,...) }
        end

        def around(execution_strategy, &steps)
          @result.then do |state|
            steps_runner = ->(dsl = self) { dsl.run(&steps) }

            _callable(execution_strategy).call(steps_runner, state)
          end
        end

        def if_true(cond, &steps)
          cond = _callable(cond)
          around(->(runner, state) { runner.call if cond.call(state) }, &steps)
        end

        def if_false(cond, &steps)
          if_true(_callable(cond) >> :!.to_proc, &steps)
        end

        alias_method :sequence, :around
        alias_method :guard, :if_true

        private

        def wrap(obj) = Result.result(obj)

        def _callable(callable)
          case callable
          when Proc # unless (callable.binding rescue nil)&.receiver == @operation
            ->(*args, **kwargs) { @operation.instance_exec(*args, **kwargs, &callable) }
          when Symbol
            ->(*args, **kwargs) { @operation.send(callable, *args, **kwargs) }
          else
            callable
          end
        end
      end
    end
  end

  Operation.plugin Plugins::Base
end

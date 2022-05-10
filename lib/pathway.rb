# frozen_string_literal: true

require 'forwardable'
require 'dry/inflector'
require 'contextualizer'
require 'pathway/version'
require 'pathway/result'

module Pathway
  Inflector = Dry::Inflector.new
  class Operation
    def self.plugin(name, *args, **kwargs)
      require "pathway/plugins/#{Inflector.underscore(name)}" if name.is_a?(Symbol)

      plugin = name.is_a?(Module) ? name : Plugins.const_get(Inflector.camelize(name))

      self.extend plugin::ClassMethods if plugin.const_defined? :ClassMethods
      self.include plugin::InstanceMethods if plugin.const_defined? :InstanceMethods
      self::DSL.include plugin::DSLMethods if plugin.const_defined? :DSLMethods

      plugin.apply(self, *args, **kwargs) if plugin.respond_to?(:apply)
    end

    def self.inherited(subclass)
      super
      subclass.const_set :DSL, Class.new(self::DSL)
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

    private

    def default_message_for(type)
      self.class.default_messages[type] || Inflector.humanize(type)
    end
  end

  class State
    extend Forwardable

    def initialize(operation, values = {})
      @hash = operation.context.merge(values)
      @result_key = operation.result_key
    end

    delegate %i([] []= fetch store include? values_at) => :@hash

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

  module Plugins
    module Base
      module ClassMethods
        attr_accessor :result_key
        alias :result_at :result_key=

        def process(&bl)
          dsl = self::DSL
          define_method(:call) do |input|
            dsl.new(State.new(self, input: input), self)
               .run(&bl)
               .then(&:result)
          end
        end

        def call(ctx, *params)
          new(ctx).call(*params)
        end

        def inherited(subclass)
          super
          subclass.result_key = result_key
        end
      end

      module InstanceMethods
        extend Forwardable

        delegate :result_key => 'self.class'
        delegate %i[result success failure] => Result

        alias :wrap :result

        def call(*)
          fail 'must implement at subclass'
        end

        def error(type, message: nil, details: nil)
          failure Error.new(type: type, message: message, details: details)
        end

        def wrap_if_present(value, type: :not_found, message: nil, details: {})
          value.nil? ? error(type, message: message, details: details) : success(value)
        end
      end

      def self.apply(klass)
        klass.extend Contextualizer
        klass.result_key = :value
      end

      module DSLMethods
        def initialize(state, operation)
          @result, @operation = wrap(state), operation
        end

        def run(&bl)
          instance_eval(&bl)
          @result
        end

        # Execute step and preserve the former state
        def step(callable, *args, **kwargs)
          bl = _callable(callable)

          @result = @result.tee { |state| bl.call(state, *args, **(state.to_h.merge(kwargs))) }
        end

        # Execute step and modify the former state setting the key
        def set(callable, *args, to: @operation.result_key, **kwargs)
          bl = _callable(callable)

          @result = @result.then do |state|
            wrap(bl.call(state, *args, **(state.to_h.merge(kwargs))))
              .then { |value| state.update(to => value) }
          end
        end

        # Execute step and replace the current state completely
        def map(callable)
          bl = _callable(callable)
          @result = @result.then(bl)
        end

        def around(wrapper, &steps)
          @result.then do |state|
            seq = -> (dsl = self) { @result = dsl.run(&steps) }
            _callable(wrapper).call(seq, state, **state.to_h)
          end
        end

        def if_true(cond, &steps)
          cond = _callable(cond)
          around(-> seq, state {
            seq.call if cond.call(state, **state.to_h)
          }, &steps)
        end

        def if_false(cond, &steps)
          cond = _callable(cond)
          if_true(-> state { !cond.call(state, **state.to_h) }, &steps)
        end

        alias_method :sequence, :around
        alias_method :guard, :if_true

        private

        def wrap(obj)
          Result.result(obj)
        end

        def _callable(callable)
          case callable
          when Proc
            -> *args, ** { @operation.instance_exec(*args, &callable) }
          when Symbol
            -> *args, **kwargs do
              has_keyword_args    = @operation.class.instance_method(callable).parameters.any? { |arg| [:keyreq, :key, :keyrest].include?(arg[0]) }
              has_positional_args = @operation.class.instance_method(callable).parameters.any? { |arg| [:req, :opt, :rest].include?(arg[0])}
              if has_positional_args
                if has_keyword_args
                  @operation.send(callable, *args, **kwargs)
                else
                  @operation.send(callable, *args)
                end
              else
                if has_keyword_args
                  @operation.send(callable, **kwargs)
                else
                  @operation.send(callable)
                end
              end
            end
          else
            callable
          end
        end
      end
    end
  end

  Operation.plugin Plugins::Base
end

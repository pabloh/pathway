# frozen_string_literal: true

require 'ruby2_keywords'
require 'forwardable'
require 'dry/inflector'
require 'contextualizer'
require 'pathway/version'
require 'pathway/result'

module Pathway
  Inflector = Dry::Inflector.new
  class Operation
    class << self
      ruby2_keywords def plugin(name, *args)
        require "pathway/plugins/#{Inflector.underscore(name)}" if name.is_a?(Symbol)

        plugin = name.is_a?(Module) ? name : Plugins.const_get(Inflector.camelize(name))

        self.extend plugin::ClassMethods if plugin.const_defined? :ClassMethods
        self.include plugin::InstanceMethods if plugin.const_defined? :InstanceMethods
        self::DSL.include plugin::DSLMethods if plugin.const_defined? :DSLMethods

        plugin.apply(self, *args) if plugin.respond_to?(:apply)
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

    def deconstruct
      [type, message, details]
    end

    def deconstruct_keys(_)
      { type: type, message: message, details: details }
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

    delegate %i([] []= fetch store include? values_at deconstruct_keys) => :@hash

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

    def use(&bl)
      raise ArgumentError, 'a block must be provided' if !block_given?
      if bl.parameters.any? {|(type,_)| type == :keyrest || type == :rest }
        raise ArgumentError, 'rest arguments are not supported'
      end

      keys = bl.parameters.select {|(type,_)| type == :key || type == :keyreq }.map(&:last)
      names = bl.parameters.select {|(type,_)| type == :req || type == :opt }.map(&:last)

      if keys.any? && names.any?
        raise ArgumentError, 'cannot mix positional and keyword arguments'
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
        alias :result_at :result_key=

        def process(&bl)
          dsl = self::DSL
          define_method(:call) do |input|
            dsl.new(State.new(self, input: input), self)
               .run(&bl)
               .then(&:result)
          end
        end

        ruby2_keywords def call(ctx, *params)
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
          failure(Error.new(type: type, message: message, details: details))
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
        ruby2_keywords def step(callable, *args)
          bl = _callable(callable)

          @result = @result.tee { |state| bl.call(state, *args) }
        end

        # Execute step and modify the former state setting the key
        def set(callable, *args, to: @operation.result_key)
          bl = _callable(callable)

          @result = @result.then do |state|
            wrap(bl.call(state, *args))
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
            _callable(wrapper).call(seq, state)
          end
        end

        def if_true(cond, &steps)
          cond = _callable(cond)
          around(-> seq, state {
            seq.call if cond.call(state)
          }, &steps)
        end

        def if_false(cond, &steps)
          cond = _callable(cond)
          if_true(-> state { !cond.call(state) }, &steps)
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
            -> *args { @operation.instance_exec(*args, &callable) }.ruby2_keywords
          when Symbol
            -> *args { @operation.send(callable, *args) }.ruby2_keywords
          else
            callable
          end
        end
      end
    end
  end

  Operation.plugin Plugins::Base
end

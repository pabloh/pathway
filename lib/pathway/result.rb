# frozen_string_literal: true

module Pathway
  class Result
    extend Forwardable
    attr_reader :value, :error

    class Success < Result
      def initialize(value) = @value = value
      def success? = true

      def then(bl = nil)
        result(block_given? ? yield(value) : bl.call(value))
      end

      def tee(...)
        follow = self.then(...)
        follow.failure? ? follow : self
      end

      private alias_method :value_for_deconstruct, :value
    end

    class Failure < Result
      def initialize(error) = @error = error
      def success? = false
      def then(_ = nil) = self
      def tee(_ = nil) = self

      private alias_method :value_for_deconstruct, :error
    end

    module Mixin
      Success = Result::Success
      Failure = Result::Failure
    end

    def self.success(value) = Success.new(value)
    def self.failure(error) = Failure.new(error)

    def self.result(object)
      object.is_a?(Result) ? object : success(object)
    end

    def failure? = !success?
    def deconstruct = [value_for_deconstruct]

    def deconstruct_keys(keys)
      if value_for_deconstruct.respond_to?(:deconstruct_keys)
        value_for_deconstruct.deconstruct_keys(keys)
      else
        {}
      end
    end

    delegate result: "self.class"
  end
end

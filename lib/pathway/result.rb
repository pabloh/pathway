# frozen_string_literal: true

module Pathway
  class Result
    extend Forwardable
    attr_reader :value, :error

    class Success < Result
      def initialize(value)
        @value = value
      end

      def success?
        true
      end

      def then(bl=nil)
        result(block_given? ? yield(value): bl.call(value))
      end

      def tee(bl=nil, &block)
        follow = self.then(bl, &block)
        follow.failure? ? follow : self
      end
    end

    class Failure < Result
      def initialize(error)
        @error = error
      end

      def success?
        false
      end

      def then(_=nil)
        self
      end

      def tee(_=nil)
        self
      end
    end

    def failure?
      !success?
    end

    def self.success(value)
      Success.new(value)
    end

    def self.failure(error)
      Failure.new(error)
    end

    def self.result(object)
      object.is_a?(Result) ? object : success(object)
    end

    delegate :result => 'self.class'
  end
end

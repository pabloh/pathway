require 'forwardable'
require 'pathway/result'
require 'pathway/error'
require 'pathway/responder'
require 'pathway/operation/flow'
require 'pathway/operation/validation'
require 'pathway/operation/authorization'
require 'pathway/operation/scoped'
require 'pathway/operation/finder'

module Pathway
  class Operation
    extend Forwardable

    include Validation
    include Authorization
    include Scoped
    include Flow

    def call(*)
      fail "must implement at subclass"
    end

    def self.call(ctx, *params, &bl)
      result = new(ctx).call(*params)
      block_given? ? Responder.respond(result, &bl) : result
    end

    private

    delegate %i[result success failure] => Result

    alias :wrap :result

    def error(type, message: nil, details: nil)
      failure Error.new(type: type, message: message, details: details)
    end

    def wrap_if_present(value, type: :not_found, message: nil, details: [])
      value.nil? ? error(type, message: message, details: details) : success(value)
    end
  end
end

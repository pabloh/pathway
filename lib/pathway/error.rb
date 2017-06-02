module Pathway
  class Error < StandardError
    ERROR_MESSAGES = {
      not_found:    'Not Found',
      forbidden:    'Forbidden',
      unauthorized: 'Unauthorized',
      validation:   'Validation failed'
    }.freeze

    attr_reader :type, :message, :details

    alias :error_type :type
    alias :error_message :message
    alias :errors :details

    def initialize(type:, message: nil, details: nil)
      @type    = type.to_sym
      @message = message || ERROR_MESSAGES[@type] || @type.to_s.tr('_', ' ').capitalize
      @details = details || {}
    end
  end
end

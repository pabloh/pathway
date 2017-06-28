require 'pathway/rspec/matchers/list_helpers'

RSpec::Matchers.define :fail_on do |input|
  match do |operation|
    @operation, @input = operation, input

    failure? && type_matches? && message_matches? && details_matches?
  end

  match_when_negated do |operation|
    raise NotImplementedError, '`expect().not_to fail_on(input).with_type()` is not supported.' if @type
    raise NotImplementedError, '`expect().not_to fail_on(input).with_message()` is not supported.' if @message
    raise NotImplementedError, '`expect().not_to fail_on(input).with_details()` is not supported.' if @details
    @operation, @input = operation, input

    !failure?
  end

  chain :type do |type|
    @type = type
  end

  alias :with_type :type
  alias :and_type :type

  chain :message do |message|
    @message = message
  end

  alias :with_message :message
  alias :and_message :message

  chain :details do |details|
    @details = details
  end

  alias :with_details :details
  alias :and_details :details

  description do
    "fail" + (@type ? " with :#@type error" : '')
  end

  failure_message do
    if !failure?
      "Expected operation to fail but it didn't"
    else
      "Expected failed operation to " +
        as_sentence(failure_descriptions, connector: '; ', last_connector: '; and ')
    end
  end

  failure_message_when_negated do
    "Did not to expected operation to fail but it did"
  end

  def failure?
    result.failure?
  end

  def type_matches?
    @type.nil? || @type == error.type
  end

  def message_matches?
    @message.nil? || values_match?(@message, error.message)
  end

  def details_matches?
    @details.nil? || values_match?(@details, error.details)
  end

  def result
    @result ||= @operation.call(@input)
  end

  def error
    result.error
  end

  def failure_descriptions
    [type_failure_description, message_failure_description, details_failure_description].compact
  end

  def type_failure_description
    type_matches? ? nil : "have type :#@type but instead was :#{error.type}"
  end

  def message_failure_description
    message_matches? ? nil : "have message like #{description_of(@message)} but instead got #{description_of(error.message)}"
  end

  def details_failure_description
    details_matches? ? nil : "have details like #{description_of(@details)} but instead got #{description_of(error.details)}"
  end

  include Pathway::Rspec::ListHelpers
end

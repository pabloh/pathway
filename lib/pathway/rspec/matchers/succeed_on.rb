# frozen_string_literal: true

RSpec::Matchers.define :succeed_on do |input|
  match do |operation|
    @operation, @input = operation, input

    success? && return_value_matches?
  end

  match_when_negated do |operation|
    raise NotImplementedError, '`expect().not_to succeed_on(input).returning()` is not supported.' if @value
    @operation, @input = operation, input

    !success?
  end

  chain :returning do |value|
    @value = value
  end

  description do
    "be successful"
  end

  failure_message do
    if !success?
      "Expected operation to be successful but failed with :#{result.error.type} error"
    else
      "Expected successful operation to return #{description_of(@value)} but instead got #{description_of(result.value)}"
    end
  end

  failure_message_when_negated do
    'Did not to expected operation to be successful but it was'
  end

  def success?
    result.success?
  end

  def return_value_matches?
    @value.nil? || values_match?(@value, result.value)
  end

  def result
    @result ||= @operation.call(@input)
  end
end

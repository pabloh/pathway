# frozen_string_literal: true

require 'pathway/rspec/matchers/form_schema_helpers'

RSpec::Matchers.define :accept_optional_fields do |*fields|
  match do |form|
    @form, @fields = form, fields

    not_defined.empty? &&
      not_optional.empty? &&
      allowing_null_values_matches? &&
      not_allowing_null_values_matches?
  end

  match_when_negated do |form|
    raise NotImplementedError, 'expect().not_to accept_optional_fields.not_allowing_null_values is not supported.' if @allowing_null_values || @not_allowing_null_values

    @form, @fields = form, fields

    not_defined.empty? && optional.empty?
  end

  description do
    null_value_allowed = @allowing_null_values ? ' allowing null values' : ''
    null_value_disallowed = @not_allowing_null_values ? ' not allowing null values' : ''
    "accept #{field_list} as optional #{pluralize_fields}#{null_value_allowed}#{null_value_disallowed}"
  end

  failure_message do
    null_value_allowed = @allowing_null_values ? ' allowing null values' : ''
    null_value_disallowed = @not_allowing_null_values ? ' not allowing null values' : ''

    "Expected to accept #{field_list} as optional #{pluralize_fields}#{null_value_allowed}#{null_value_disallowed} but " +
      [not_optional_list, not_defined_list, accepting_null_list, not_accepting_null_list].compact.join("; and ")
  end

  failure_message_when_negated do
    "Did not expect to accept #{field_list} as optional #{pluralize_fields} but " +
      [optional_list, not_defined_list].compact.join("; and ")
  end

  include Pathway::Rspec::FormSchemaHelpers

  def optional_list
    "#{as_list(optional)} #{were_was(optional)} optional" if optional.any?
  end

  def not_optional_list
    "#{as_list(not_optional)} #{were_was(not_optional)} not optional" if not_optional.any?
  end

  chain :allowing_null_values do
    fail 'cannot use allowing_null_values and not_allowing_null_values at the same time' if @not_allowing_null_values

    @allowing_null_values = true
  end

  chain :not_allowing_null_values do
    fail 'cannot use allowing_null_values and not_allowing_null_values at the same time' if @allowing_null_values

    @not_allowing_null_values = true
  end
end

RSpec::Matchers.alias_matcher :accept_optional_field, :accept_optional_fields

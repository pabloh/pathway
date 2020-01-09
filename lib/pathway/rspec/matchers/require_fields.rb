# frozen_string_literal: true

require 'pathway/rspec/matchers/form_schema_helpers'

RSpec::Matchers.define :require_fields do |*fields|
  match do |form|
    @form, @fields = form, fields

    not_defined.empty? &&
      not_required.empty? &&
      allowing_null_values_matches? &&
      not_allowing_null_values_matches?
  end

  match_when_negated do |form|
    raise NotImplementedError, 'expect().not_to require_fields.not_allowing_null_values is not supported.' if @allowing_null_values || @not_allowing_null_values

    @form, @fields = form, fields

    not_defined.empty? && required.empty?
  end

  description do
    null_value_allowed = @allowing_null_values ? ' allowing null values' : ''
    null_value_disallowed = @not_allowing_null_values ? ' not allowing null values' : ''
    "require #{field_list} as #{pluralize_fields}#{null_value_allowed}#{null_value_disallowed}"
  end

  failure_message do
    null_value_allowed = @allowing_null_values ? ' allowing null values' : ''
    null_value_disallowed = @not_allowing_null_values ? ' not allowing null values' : ''

    "Expected to require #{field_list} as #{pluralize_fields}#{null_value_allowed}#{null_value_disallowed}  but " +
      [not_required_list, not_defined_list, accepting_null_list, not_accepting_null_list].compact.join("; and ")
  end

  failure_message_when_negated do
    "Did not expect to require #{field_list} as #{pluralize_fields} but " +
      [required_list, not_defined_list].compact.join("; and ")
  end

  include Pathway::Rspec::FormSchemaHelpers

  def required_list
    "#{as_list(required)} #{were_was(required)} required" if required.any?
  end

  def not_required_list
    "#{as_list(not_required)} #{were_was(not_required)} not required" if not_required.any?
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

RSpec::Matchers.alias_matcher :require_field, :require_fields

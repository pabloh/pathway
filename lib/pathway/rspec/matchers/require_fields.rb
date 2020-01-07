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
    @form, @fields = form, fields

    not_defined.empty? &&
      required.empty? &&
      allowing_null_values_matches? &&
      not_allowing_null_values_matches?
  end

  description do
    null_value_allowed = @allowing_null_values ? ' allowing null values' : ''
    null_value_disallowed = @not_allowing_null_values ? ' not allowing null values' : ''
    "require #{field_list} as #{pluralize_fields}#{null_value_allowed}#{null_value_disallowed}"
  end

  failure_message do
    "Expected to require #{field_list} as #{pluralize_fields} but " +
      [not_required_list, not_defined_list, accepting_null_list, not_accepting_null_list].compact.join("; and ")
  end

  failure_message_when_negated do
    "Did not expect to require #{field_list} as #{pluralize_fields} but " +
      [required_list, not_defined_list, accepting_null_list, not_accepting_null_list].compact.join("; and ")
  end

  include Pathway::Rspec::FormSchemaHelpers

  def required_list
    "#{as_list(required)} #{were_was(required)} required" if required.any?
  end

  def not_required_list
    "#{as_list(not_required)} #{were_was(not_required)} not required" if not_required.any?
  end

  def accepting_null_list
    "#{as_list(null_value_allowed)} #{were_was(null_value_allowed)} accepting null value" if null_value_allowed.any?
  end

  def not_accepting_null_list
    "#{as_list(null_value_disallowed)} #{were_was(null_value_disallowed)} not accepting null value" if null_value_disallowed.any?
  end

  chain :allowing_null_values do
    @allowing_null_values = true
  end

  chain :not_allowing_null_values do
    @not_allowing_null_values = true
  end

  def allowing_null_values_matches?
    @allowing_null_values ? @fields.all? { |field| null_value_allowed?(field) } : true
  end

  def not_allowing_null_values_matches?
    @not_allowing_null_values ? @fields.all? { |field| null_value_disallowed?(field) } : true
  end
end

RSpec::Matchers.alias_matcher :require_field, :require_fields

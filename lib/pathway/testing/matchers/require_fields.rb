require 'pathway/testing/matchers/form_schema_helpers'

RSpec::Matchers.define :require_fields do |*fields|
  match do |form|
    @form, @fields = form, fields

    not_defined.empty? && not_required.empty?
  end

  match_when_negated do |form|
    @form, @fields = form, fields

    not_defined.empty? && required.empty?
  end

  description do
    "require #{field_list} as #{pluralize_fields}"
  end

  failure_message do
    "Expected to require #{field_list} as #{pluralize_fields} but " +
      [not_required_list, not_defined_list].compact.join("; and ")
  end

  failure_message_when_negated do
    "Did not expect to require #{field_list} as #{pluralize_fields} but " +
      [required_list, not_defined_list].compact.join("; and ")
  end

  include FormSchemaHelpers

  def required_list
    "#{as_list(required)} #{were_was(required)} required" if required.any?
  end

  def not_required_list
    "#{as_list(not_required)} #{were_was(not_required)} not required" if not_required.any?
  end
end

RSpec::Matchers.alias_matcher :require_field, :require_fields

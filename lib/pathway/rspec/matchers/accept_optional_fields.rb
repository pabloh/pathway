require 'pathway/rspec/matchers/form_schema_helpers'

RSpec::Matchers.define :accept_optional_fields do |*fields|
  match do |form|
    @form, @fields = form, fields

    not_defined.empty? && not_optional.empty?
  end

  match_when_negated do |form|
    @form, @fields = form, fields

    not_defined.empty? && optional.empty?
  end

  description do
    "accept #{field_list} as optional #{pluralize_fields}"
  end

  failure_message do
    "Expected to accept #{field_list} as optional #{pluralize_fields} but " +
      [not_optional_list, not_defined_list].compact.join("; and ")
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
    "#{as_list(not_required)} #{were_was(not_required)} not optional" if not_optional.any?
  end
end

RSpec::Matchers.alias_matcher :accept_optional_field, :accept_optional_fields

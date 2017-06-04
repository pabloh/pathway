require 'pathway/testing/matchers/list_helpers'

module FieldListHelpers
  include ListHelpers

  def field_list
    as_list(@fields)
  end

  def were_was(list)
    list.size > 1 ? "were" : "was"
  end

  def pluralize_fields
    @fields.size > 1 ? "fields" : "field"
  end
end

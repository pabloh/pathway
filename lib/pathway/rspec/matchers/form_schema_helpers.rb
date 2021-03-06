# frozen_string_literal: true

require 'pathway/rspec/matchers/field_list_helpers'

module Pathway
  module Rspec
    module FormSchemaHelpers
      include FieldListHelpers

      if defined?(::Dry::Validation::Contract)
        def rules
          @form.schema.rules
        end
      else
        def rules
          @form.rules
        end
      end

      def not_defined_list
        "#{as_list(not_defined)} #{were_was(not_defined)} not defined" if not_defined.any?
      end

      def accepting_null_list
        "#{as_list(null_value_allowed)} #{were_was(null_value_allowed)} accepting null values" if @not_allowing_null_values && null_value_allowed.any?
      end

      def not_accepting_null_list
        "#{as_list(null_value_disallowed)} #{were_was(null_value_disallowed)} not accepting null values" if @allowing_null_values && null_value_disallowed.any?
      end

      def required
        @required ||= @fields.select { |field| required?(field) }
      end

      def optional
        @optional ||= @fields.select { |field| optional?(field) }
      end

      def null_value_allowed
        @null_value_allowed ||= @fields.select { |field| null_value_allowed?(field) }
      end

      def null_value_disallowed
        @null_value_disallowed ||= @fields.select { |field| null_value_disallowed?(field) }
      end

      def not_required
        @not_required ||= defined - required
      end

      def not_optional
        @not_optional ||= defined - optional
      end

      def not_defined
        @not_defined ||= @fields - defined
      end

      def defined
        @defined ||= @fields & rules.keys
      end

      def optional?(field)
        if rules[field]&.type == :implication
          left = rules[field].left

          left.type == :predicate && left.name == :key? && left.args.first == field
        end
      end

      def required?(field)
        if rules[field]&.type == :and
          left = rules[field].left

          left.type == :predicate && left.name == :key? && left.args.first == field
        end
      end

      def allowing_null_values_matches?
        @allowing_null_values ? @fields.all? { |field| null_value_allowed?(field) } : true
      end

      def not_allowing_null_values_matches?
        @not_allowing_null_values ? @fields.all? { |field| null_value_disallowed?(field) } : true
      end

      def null_value_allowed?(field)
        rule = rules[field]&.right&.rule
        predicate = rule&.left
        predicate.present? && predicate.type == :not && predicate.rules&.first&.name == :nil?
      end

      def null_value_disallowed?(field)
        rule = rules[field]&.right&.rule
        predicate = rule&.left
        predicate.present? && predicate.type == :predicate && predicate.name == :filled?
      end
    end
  end
end

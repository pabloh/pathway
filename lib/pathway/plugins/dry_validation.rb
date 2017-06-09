require 'pathway/form'

module Pathway
  module Plugins
    module DryValidation
      module ClassMethods
        attr_reader :form_class

        def form(base = nil, **opts, &block)
          if block_given?
            base ||= _base_form 
            self.form_class = Dry::Validation.Form(_form_class(base), _opts(opts), &block)
          elsif base
            self.form_class = _form_class(base)
          else
            raise ArgumentError, 'Either a form class or a block must be provided'
          end
        end

        def form_class= klass
          @builded_form = klass.options.empty? ? klass.new : nil
          @form_class = klass
        end

        def build_form(opts = {})
          @builded_form || form_class.new(opts)
        end

        def inherited(subclass)
          super
          subclass.form_class = form_class
        end

        private

        def _base_form
          superclass.respond_to?(:form_class) ? superclass.form_class : Pathway::Form
        end

        def _form_class(form)
          form.is_a?(Class) ? form : form.class
        end

        def _opts(opts = {})
          opts.merge(build: false)
        end
      end

      module InstanceMethods
        extend Forwardable

        delegate :build_form => 'self.class'
        alias :form :build_form

        def validate(state)
          validate_with(state[:input])
            .then { |params| state.update(params: params) }
        end

        def validate_with(params, opts = {})
          val = form(opts).call(params)

          val.success? ? wrap(val.output) : error(:validation, details: val.messages)
        end
      end

      def self.apply(operation)
        operation.form_class = Pathway::Form
      end
    end
  end
end

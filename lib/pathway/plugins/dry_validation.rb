require 'dry/validation'

module Pathway
  module Plugins
    module DryValidation
      module ClassMethods
        attr_reader :form_class, :form_options
        attr_accessor :auto_wire_options

        def form(base = nil, **opts, &block)
          if block_given?
            base ||= _base_form
            self.form_class = _block_definition(base, opts, &block)
          elsif base
            self.form_class = _form_class(base)
          else
            raise ArgumentError, 'Either a form class or a block must be provided'
          end
        end

        def form_class= klass
          @builded_form = klass.options.empty? ? klass.new : nil
          @form_class = klass
          @form_options = klass.options.keys
        end

        def build_form(opts = {})
          @builded_form || form_class.new(opts)
        end

        def inherited(subclass)
          super
          subclass.form_class = form_class
          subclass.auto_wire_options = auto_wire_options
        end

        private

        def _base_form
          superclass.respond_to?(:form_class) ? superclass.form_class : DefaultFormClass
        end

        def _form_class(form)
          form.is_a?(Class) ? form : form.class
        end

        def _form_opts(opts = {})
          opts.merge(build: false)
        end
      end

      module InstanceMethods
        extend Forwardable

        delegate %i[build_form form_options auto_wire_options] => 'self.class'
        alias :form :build_form

        def validate(state, with: nil)
          if auto_wire_options && form_options.any?
            with ||= form_options.zip(form_options).to_h
          end
          opts = Hash(with).map { |opt, key| [opt, state[key]] }.to_h
          validate_with(state[:input], opts)
            .then { |params| state.update(params: params) }
        end

        def validate_with(params, opts = {})
          val = form(opts).call(params)

          val.success? ? wrap(val.output) : error(:validation, details: val.messages)
        end
      end

      def self.apply(operation, auto_wire_options: false)
        operation.form_class = DefaultFormClass
        operation.auto_wire_options = auto_wire_options
      end

      if Dry::Validation::VERSION[/\A0\.(\d+).\d+\Z/, 1].to_i >= 12
        DefaultFormClass = Dry::Validation::Schema::Params

        module ClassMethods
          private
          def _block_definition(base, opts, &block)
            Dry::Validation.Params(_form_class(base), _form_opts(opts), &block)
          end
        end
      else
        DefaultFormClass = Dry::Validation::Schema::Form

        module ClassMethods
          private
          def _block_definition(base, opts, &block)
            Dry::Validation.Form(_form_class(base), _form_opts(opts), &block)
          end
        end
      end
    end
  end
end

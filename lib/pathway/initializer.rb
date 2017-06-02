module Pathway
  module Initializer
    def self.[](*attrs, **opt_attrs)

      Module.new do |mod|
        all_attrs = attrs + opt_attrs.keys

        mod.define_singleton_method :included do |klass|
          klass.send(:attr_accessor, *all_attrs)
          klass.send(:attr_reader, :context) unless klass.instance_methods.include?(:context)
        end

        mod.send(:define_method, :initialize) do |args|
          super(args)
          local_ctx = all_attrs.zip(all_attrs.map { |k| args[k].nil? ? opt_attrs[k] : args[k] }).to_h

          local_ctx.each do |attr, value|
            fail ":#{attr} was not found in scope" if value.nil?
            self.send :"#{attr}=", value
          end

          @context = (@context || {}).merge(local_ctx).freeze
        end
      end

    end
  end
end

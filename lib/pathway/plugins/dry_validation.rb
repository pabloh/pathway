# frozen_string_literal: true

require 'dry/validation'

module Pathway
  module Plugins
    module DryValidation
      def self.apply(operation, **kwargs)
        #:nocov:
        if Gem.loaded_specs['dry-validation'].version < Gem::Version.new('0.11')
          fail 'unsupported dry-validation gem version'
        elsif Gem.loaded_specs['dry-validation'].version < Gem::Version.new('0.12')
          require 'pathway/plugins/dry_validation/v0_11'
          operation.plugin(Plugins::DryValidation::V0_11, **kwargs)
        elsif Gem.loaded_specs['dry-validation'].version < Gem::Version.new('1.0')
          require 'pathway/plugins/dry_validation/v0_12'
          operation.plugin(Plugins::DryValidation::V0_12, **kwargs)
        else
          require 'pathway/plugins/dry_validation/v1_0'
          operation.plugin(Plugins::DryValidation::V1_0, **kwargs)
        end
        #:nocov:
      end
    end
  end
end

# frozen_string_literal: true

module Pathway
  module Rspec
    module ListHelpers
      def as_list(items)
        as_sentence(items.map(&:inspect))
      end

      def as_sentence(items, connector: ", ", last_connector: " and ")
        *rest, last = items

        result = String.new
        result << rest.join(connector) << last_connector if rest.any?
        result << last
      end
    end
  end
end

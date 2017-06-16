require 'pathway/responder'

module Pathway
  module Plugins
    module Responder
      module ClassMethods
        def call(ctx, *params, &bl)
          result = new(ctx).call(*params)
          block_given? ? Pathway::Responder.respond(result, &bl) : result
        end
      end
    end
  end
end

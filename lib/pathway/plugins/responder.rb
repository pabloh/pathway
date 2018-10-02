module Pathway
  module Plugins
    module Responder
      module ClassMethods
        def call(ctx, *params, &bl)
          result = new(ctx).call(*params)
          block_given? ? Responder.respond(result, &bl) : result
        end
      end

      class Responder
        def self.respond(result, &bl)
          r = new(result, &bl)
          r.respond
        end

        def initialize(result, &bl)
          @result, @context, @fails = result, bl.binding.receiver, {}
          instance_eval(&bl)
        end

        def success(&bl)
          @ok = bl
        end

        def failure(type = nil, &bl)
          if type.nil?
            @fail_default = bl
          else
            @fails[type] = bl
          end
        end

        def respond
          if @result.success?
            @context.instance_exec(@result.value, &@ok)
          elsif Error === @result.error && fail_block = @fails[@result.error.type]
            @context.instance_exec(@result.error, &fail_block)
          else
            @context.instance_exec(@result.error, &@fail_default)
          end
        end
      end
    end
  end
end

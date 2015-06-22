module Escher
  module Request
    class Factory

      def self.from_request(request)
        case request

          when defined?(ActionDispatch::Request) && ActionDispatch::Request
            ActionDispatchRequest.new(request)

          when defined?(Rack::Request) && Rack::Request
            RackRequest.new(request)

          when Hash
            HashRequest.new(request)

          else
            Escher::Request::LegacyRequest.new(request)

        end
      end

    end
  end
end

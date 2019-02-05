module Escher
  module Request
    class Factory

      def self.from_request(request)
        case request

          when defined?(ActionDispatch::Request) && ActionDispatch::Request
            RackRequest.new(Rack::Request.new(request.env))

          when defined?(Rack::Request) && Rack::Request
            RackRequest.new(request)
          when Net::HTTPRequest
            NetHttpRequest.new(request)
          when Hash
            HashRequest.new(request)

          else
            Escher::Request::LegacyRequest.new(request)

        end
      end

    end
  end
end

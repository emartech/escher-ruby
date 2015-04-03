require 'escher/request/base'
require 'escher/request/hash_request'
require 'escher/request/rack_request'
require 'escher/request/legacy_request'
require 'escher/request/action_dispatch_request'

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

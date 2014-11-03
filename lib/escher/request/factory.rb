require_relative 'base'

require_relative 'hash_request'
require_relative 'legacy_request'
require_relative 'rack_request'

module Escher
  module Request
    class Factory

      def self.from_request(request)
        case request.class.to_s
          when 'Hash'
            HashRequest.new request
          when 'Rack::Request'
            RackRequest.new request
          else
            Escher::Request::LegacyRequest.new request
        end
      end

    end
  end
end

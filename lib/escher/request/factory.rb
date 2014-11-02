require_relative 'hash_request'
require_relative 'legacy_request'

module Escher
  module Request
    class Factory

      def self.from_request(request)
        case request
          when Hash
            HashRequest.new request
          else
            Escher::Request::LegacyRequest.new request
        end
      end

    end
  end
end

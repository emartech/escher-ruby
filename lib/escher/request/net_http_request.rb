module Escher
  module Request
    class NetHttpRequest < Base
      def path
        URI(request.path).path
      end

      def headers
        request.each_header.to_a
      end

      def has_header?(header_key)
        !!request[header_key]
      end

      def header(header_key)
        request[header_key]
      end

      def method
        request.method
      end

      def body
        request.body || ''
      end

      def query_values
        Addressable::URI.parse(request.path).query_values(Array) || []
      end

      def set_header(key, value)
        request.add_field(key, value)
      end
    end
  end
end

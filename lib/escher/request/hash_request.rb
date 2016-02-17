module Escher
  module Request
    class HashRequest < Base

      # Based on the example in RFC 3986, but scheme, user, password,
      # host, port and fragment support removed, only path and query left
      URI_REGEXP = /^([^?#]*)(\?(.*))?$/



      def initialize(request)
        super request
      end



      def headers
        request[:headers].map { |(header_name, value)| [header_name.gsub('_', '-'), value] }
      end



      def set_header(name, value)
        request[:headers] ||= []
        request[:headers] << [name, value] unless has_header? name
      end



      def method
        request[:method]
      end



      def body
        request[:body] or ''
      end



      def path
        request[:uri].match(URI_REGEXP)[1]
      end



      def query_values
        query = request[:uri].match(URI_REGEXP)[3]
        (Addressable::URI.new query: query).query_values(Array) or []
      end

    end
  end
end

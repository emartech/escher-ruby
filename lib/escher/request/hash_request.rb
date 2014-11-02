module Escher
  module Request
    class HashRequest

      # Based on the example in RFC 3986, but scheme, user, password,
      # host, port and fragment support removed, only path and query left
      URI_REGEXP = /^([^?#]*)(\?(.*))?$/

      attr_reader :request



      def initialize(request)
        @request = request
        @uri = parse_uri request[:uri]
      end



      def headers
        request[:headers].map { |(header_name, value)| [header_name.gsub('_', '-'), value] }
      end



      def has_header?(name)
        not header(name).nil?
      end



      def header(name)
        header = headers.find { |(header_name, _)| header_name.downcase == name.downcase }
        return nil if header.nil?
        header[1]
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
        @uri.path
      end



      def query_values
        @uri.query_values(Array) or []
      end



      private

      def parse_uri(uri)
        uri.match URI_REGEXP do |match_data|
          Addressable::URI.new({:path => match_data[1],
                                :query => match_data[3]})
        end
      end

    end

  end
end

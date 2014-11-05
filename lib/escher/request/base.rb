module Escher
  module Request
    class Base

      attr_reader :request



      def initialize(request)
        @request = request
      end



      def has_header?(name)
        not header(name).nil?
      end



      def header(name)
        header = headers.find { |(header_name, _)| header_name.downcase == name.downcase }
        return nil if header.nil?
        header[1]
      end

    end
  end
end
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



      def method
        raise("Implementation missing for #{__method__}")
      end



      def body
        raise("Implementation missing for #{__method__}")
      end



      def headers
        raise('Implementation missing, should return array of array with [key,value] pairs')
      end



      def path
        raise("Implementation missing for #{__method__}")
      end



      def query_values
        raise("Implementation missing for #{__method__}")
      end




    end
  end
end
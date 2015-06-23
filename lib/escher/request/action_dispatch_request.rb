module Escher
  module Request
    class ActionDispatchRequest < Base

      include Escher::Request::DCI::RackEnv

      def headers
        get_headers_by_rack_env(request.env)
      end



      def method
        request.request_method
      end



      def body
        case request.body
        when StringIO
          request.body.string
        else
          request.body.to_s
        end
      end



      def path
        request.env['REQUEST_PATH'] || request.path
      end



      def query_values
        Addressable::URI.new(:query => request.env['QUERY_STRING']).query_values(Array) or []
      end



      def set_header(header_name, value)
      end

    end
  end
end

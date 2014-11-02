module Escher
  module Request
    class LegacyRequest

      # based on the example in RFC 3986, but scheme, user, password,
      # host, port and fraement support removed, only path and query left
      URIREGEX = /^([^?#]*)(\?(.*))?$/



      def initialize(request)
        @request = request
        prepare_request_uri
        prepare_request_headers
      end



      def prepare_request_uri
        case @request.class.to_s
          when 'Hash'
            uri = @request[:uri]
          else
            uri = @request.uri
        end
        fragments = uri.scan(URIREGEX)[0]
        @request_uri = Addressable::URI.new({
                                              :path => fragments[0],
                                              :query => fragments[2],
                                            })
        raise "Invalid request URI: #{@request_uri}" unless @request_uri
      end



      def prepare_request_headers
        @request_headers = []
        case @request.class.to_s
          when 'Hash'
            @request_headers = @request[:headers]
          when 'Sinatra::Request' # TODO: not working yet
            @request.env.each { |key, value|
              if key.downcase[0, 5] == "http_"
                @request_headers += [[key[5..-1].gsub("_", "-"), value]]
              end
            }
          when 'WEBrick::HTTPRequest'
            @request.header.each { |key, values|
              values.each { |value|
                @request_headers += [[key, value]]
              }
            }
        end
      end



      def request
        @request
      end



      def headers
        @request_headers
      end



      def set_header(key, value)
        found = false
        @request_headers.each { |header|
          if not found and header[0].downcase == key.downcase
            header[1] = value
            found = true
          end
        }
        unless found
          @request_headers += [[key, value]]
        end
        case @request.class.to_s
          when 'Hash'
            @request[:headers] = @request_headers
          else
            @request[key] = value
        end
      end



      def has_header?(key)
        @request_headers.each { |header|
          if header[0].downcase == key.downcase
            return true
          end
        }
        return false
      end



      def method
        case @request.class.to_s
          when 'Hash'
            @request[:method]
          else
            @request.request_method
        end
      end



      # TODO: create a test for empty body (= nil)
      def body
        case @request.class.to_s
          when 'Hash'
            @request[:body] || ''
          else
            @request.body || ''
        end
      end



      def host
        @request_headers.each { |header|
          if header[0].downcase == key.downcase
            return header[1]
          end
        }
        case @request.class.to_s
          when 'Hash'
            @request[:host]
          else
            begin
              @request.host
            rescue
              ""
            end
        end
      end



      def path
        @request_uri.path
      end



      def query_values
        @request_uri.query_values(Array) || []
      end

    end
  end
end

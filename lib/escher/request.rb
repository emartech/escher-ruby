
class EscherRequest

  def initialize(request)
    @request = request
    @request_uri = Addressable::URI.parse(uri)
    prepare_request_headers
  end

  def prepare_request_headers
    @request_headers = []
    case @request.class.to_s
      when 'Hash'
        @request_headers = @request[:headers]
      when 'Sinatra::Request' # TODO: not working yet
        @request.env.each { |key, value|
          if key.downcase[0, 5] == "http_"
            @request_headers += [[ key[5..-1].gsub("_", "-"), value ]]
          end
        }
      when 'WEBrick::HTTPRequest'
        @request.header.each { |key, values|
          values.each { |value|
            @request_headers += [[ key, value ]]
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
    @request[key] = value
  end

  def method
    case @request.class.to_s
      when 'Hash'
        @request[:method]
      else
        @request.request_method
    end
  end

  def uri
    case @request.class.to_s
      when 'Hash'
        @request[:uri]
      else
        @request.uri
    end
  end

  def body
    case @request.class.to_s
      when 'Hash'
        @request[:body]
      else
        @request.body
    end
  end

  def path
    @request_uri.path
  end

  def query_values
    @request_uri.query_values(Array) || []
  end

end

class Escher::Request::RackRequest < Escher::Request::Base

  include Escher::Request::DCI::RackEnv

  def initialize(request_env)
    super(request_env)
    @rack_request = request_env
  end

  def env
    @rack_request.env
  end

  def rack_request
    @rack_request
  end

  def uri
    @rack_request.env['REQUEST_URI']
  end

  def path
    @rack_request.env['REQUEST_PATH']
  end

  def host
    @rack_request.env['HTTP_HOST']
  end

  def headers
    @headers ||= get_headers_by_rack_env(@rack_request.env)
  end

  def method
    @rack_request.request_method rescue @rack_request.env['REQUEST_METHOD']
  end

  def payload
    @payload ||= fetch_payload
  end

  alias body payload

  def query_values
    Addressable::URI.new(:query => request.env['QUERY_STRING']).query_values(Array) or []
  end

  def set_header(header_name, value)
  end

  protected

  def fetch_payload
    rack_input = @rack_request.body

    return rack_input.to_s if rack_input.nil? || rack_input.is_a?(String)

    payload = rack_input.read
    @rack_request.body.rewind
    payload

  end

end
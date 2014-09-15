require 'escher/version'

require 'time'
require 'digest'
require 'pathname'
require 'addressable/uri'

class EscherError < RuntimeError
end

class Escher

  def initialize(credential_scope, options)
    @credential_scope = credential_scope
    @algo_prefix      = options[:algo_prefix]      || 'ESR'
    @vendor_key       = options[:vendor_key]       || 'Escher'
    @hash_algo        = options[:hash_algo]        || 'SHA256'
    @current_time     = options[:current_time]     || Time.now
    @auth_header_name = options[:auth_header_name] || 'X-Escher-Auth'
    @date_header_name = options[:date_header_name] || 'X-Escher-Date'
    @clock_skew       = options[:clock_skew]       || 900
  end

  def sign!(req, client)
    request = EscherRequest.new(req)
    auth_header = generate_auth_header(client, request.method, uri_parsed.host, uri_parsed.path, request.body || '', request.to_enum.to_a, [])

    request.setHeader('Host', request.host) # TODO: we shouldn't remove port from Host here
    request.setHeader(@date_header_name, format_date_for_header)
    request.setHeader(@auth_header_name, auth_header)
    request
  end

  def validate(req, key_db)
    validate_request(req, key_db)
  end

  def is_valid?(*args)
    begin
      validate(*args)
      return true
    rescue
      return false
    end
  end

  def validate_request(req, key_db)
    request = EscherRequest.new(req)
    method = request.method
    body = request.body
    headers = request.headers
    path = request.path
    query_parts = request.query_values

    signature_from_query = get_signing_param('Signature', query_parts)

    validate_headers(headers, signature_from_query)

    if method == 'GET' && signature_from_query
      raw_date = get_signing_param('Date', query_parts)
      algorithm, api_key_id, short_date, credential_scope, signed_headers, signature, expires = get_auth_parts_from_query(query_parts)

      body = 'UNSIGNED-PAYLOAD'
      query_parts.delete [query_key_for('Signature'), signature]
      query_parts = query_parts.map { |k, v| [uri_decode(k), uri_decode(v)] }
    else
      raw_date = get_header(@date_header_name, headers)
      auth_header = get_header(@auth_header_name, headers)
      algorithm, api_key_id, short_date, credential_scope, signed_headers, signature, expires = get_auth_parts_from_header(auth_header)
    end

    date = Time.parse(raw_date)
    api_secret = key_db[api_key_id]

    raise EscherError, 'Invalid API key' unless api_secret
    raise EscherError, 'Only SHA256 and SHA512 hash algorithms are allowed' unless %w(SHA256 SHA512).include?(algorithm)
    raise EscherError, 'Invalid request date' unless short_date(date) == short_date
    raise EscherError, 'The request date is not within the accepted time range' unless is_date_within_range?(date, expires)
    raise EscherError, 'Invalid credentials' unless credential_scope == @credential_scope
    raise EscherError, 'Host header is not signed' unless signed_headers.include? 'host'
    raise EscherError, 'Only the host header should be signed' if signature_from_query && signed_headers != ['host']
    raise EscherError, 'Date header is not signed' if !signature_from_query && !signed_headers.include?(@date_header_name.downcase)

    escher = reconfig(algorithm, credential_scope, date)
    expected_signature = escher.generate_signature(api_secret, body, headers, method, signed_headers, path, query_parts)
    raise EscherError, 'The signatures do not match' unless signature == expected_signature
  end

  def validate_headers(headers, using_query_string_for_validation)
    (['Host'] + (using_query_string_for_validation ? [] : [@auth_header_name, @date_header_name])).each do |header|
      raise EscherError, 'Missing header: ' + header unless get_header(header, headers)
    end
  end

  def reconfig(algorithm, credential_scope, date)
    Escher.new(
        credential_scope,
        algo_prefix: @algo_prefix,
        vendor_key: @vendor_key,
        hash_algo: algorithm,
        auth_header_name: @auth_header_name,
        date_header_name: @date_header_name,
        current_time: date
    )
  end

  def generate_auth_header(client, method, host, request_uri, body, headers, headers_to_sign)
    path, query_parts = parse_uri(request_uri)
    headers = add_defaults_to(headers, host)
    headers_to_sign |= [@date_header_name.downcase, 'host']
    signature = generate_signature(client[:api_secret], body, headers, method, headers_to_sign, path, query_parts)
    "#{get_algorithm_id} Credential=#{client[:api_key_id]}/#{short_date(@current_time)}/#{@credential_scope}, SignedHeaders=#{prepare_headers_to_sign headers_to_sign}, Signature=#{signature}"
  end

  def generate_signed_url(url_to_sign, client, expires = 86400)
    uri = Addressable::URI.parse(url_to_sign)
    protocol = uri.scheme
    host = uri.host
    path = uri.path
    query_parts = parse_query(uri.query)

    headers = [['host', host]]
    headers_to_sign = ['host']
    body = 'UNSIGNED-PAYLOAD'
    query_parts += get_signing_params(client, expires, headers_to_sign)

    signature = generate_signature(client[:api_secret], body, headers, 'GET', headers_to_sign, path, query_parts)
    query_parts_with_signature = (query_parts.map { |k, v| [uri_encode(k), uri_encode(v)] } << query_pair('Signature', signature))

    protocol + '://' + host + path + '?' + query_parts_with_signature.map { |k, v| k + '=' + v }.join('&')
  end

  def get_signing_params(client, expires, headers_to_sign)
    [
        ['Algorithm', get_algorithm_id],
        ['Credentials', "#{client[:api_key_id]}/#{short_date(@current_time)}/#{@credential_scope}"],
        ['Date', long_date(@current_time)],
        ['Expires', expires.to_s],
        ['SignedHeaders', headers_to_sign.join(';')],
    ].map { |k, v| query_pair(k, v) }
  end

  def query_pair(k, v)
    [query_key_for(k), v]
  end

  def query_key_for(key)
    "X-#{@vendor_key}-#{key}"
  end

  def query_key_truncate(key)
    key[@vendor_key.length + 3..-1]
  end

  def get_header(header_name, headers)
    the_header = (headers.detect { |header| header[0].downcase == header_name.downcase })
    the_header ? the_header[1] : nil
  end

  def get_signing_param(key, query_parts)
    the_param = (query_parts.detect { |param| param[0] === query_key_for(key) })
    the_param ? uri_decode(the_param[1]) : nil
  end

  def get_auth_parts_from_header(auth_header)
    m = /#{@algo_prefix}-HMAC-(?<algo>[A-Z0-9\,]+) Credential=(?<api_key_id>[A-Za-z0-9\-_]+)\/(?<short_date>[0-9]{8})\/(?<credentials>[A-Za-z0-9\-_\/]+), SignedHeaders=(?<signed_headers>[A-Za-z\-;]+), Signature=(?<signature>[0-9a-f]+)$/
    .match auth_header
    raise EscherError, 'Malformed authorization header' unless m && m['credentials']
    return m['algo'], m['api_key_id'], m['short_date'], m['credentials'], m['signed_headers'].split(';'), m['signature'], 0
  end

  def get_auth_parts_from_query(query_parts)
    expires = get_signing_param('Expires', query_parts).to_i
    api_key_id, short_date, credential_scope = get_signing_param('Credentials', query_parts).split('/', 3)
    signed_headers = get_signing_param('SignedHeaders', query_parts).split ';'
    algorithm = parse_algo(get_signing_param('Algorithm', query_parts))
    signature = get_signing_param('Signature', query_parts)
    return algorithm, api_key_id, short_date, credential_scope, signed_headers, signature, expires
  end

  def generate_signature(api_secret, body, headers, method, signed_headers, path, query_parts)
    canonicalized_request = canonicalize(method, path, query_parts, body, headers, signed_headers.uniq)
    string_to_sign = get_string_to_sign(canonicalized_request)
    signing_key = calculate_signing_key(api_secret)
    Digest::HMAC.hexdigest(string_to_sign, signing_key, create_algo)
  end

  def add_defaults_to(headers, host)
    [['host', host], [@date_header_name, format_date_for_header]]
      .each { |k, v| headers = add_if_missing headers, k, v }
    headers
  end

  def format_date_for_header
    @date_header_name.downcase == 'date' ? @current_time.utc.rfc2822.sub('-0000', 'GMT') : long_date(@current_time)
  end

  def add_if_missing(headers, header_to_find, value)
    headers += [header_to_find, value] unless headers.find { |header| header[0].downcase == header_to_find.downcase }
    headers
  end

  def canonicalize(method, path, query_parts, body, headers, headers_to_sign)    [
      method,
      canonicalize_path(path),
      canonicalize_query(query_parts),
      canonicalize_headers(headers, headers_to_sign).join("\n"),
      '',
      prepare_headers_to_sign(headers_to_sign),
      create_algo.new.hexdigest(body || '') # TODO: we should set the default value at the same level at every implementation
    ].join "\n"
  end

  def prepare_headers_to_sign(headers_to_sign)
    headers_to_sign.sort.uniq.join(';')
  end

  def parse_uri(request_uri)
    path, query = request_uri.split '?', 2
    return path, parse_query(query)
  end

  def parse_query(query)
    (query || '')
    .split('&', -1)
    .map { |pair| pair.split('=', -1) }
    .map { |k, v| (k.include?' ') ? [k.str(/\S+/), ''] : [k, v] }
  end

  def get_string_to_sign(canonicalized_req)
    [
      get_algorithm_id,
      long_date(@current_time),
      short_date(@current_time) + '/' + @credential_scope,
      create_algo.new.hexdigest(canonicalized_req)
    ].join("\n")
  end

  def create_algo
    case @hash_algo
      when 'SHA256'
        return Digest::SHA2.new 256
      when 'SHA512'
        return Digest::SHA2.new 512
      else
        raise EscherError, 'Unidentified hash algorithm'
    end
  end

  def long_date(date)
    date.utc.strftime('%Y%m%dT%H%M%SZ')
  end

  def short_date(date)
    date.utc.strftime('%Y%m%d')
  end

  def is_date_within_range?(request_date, expires)
    (request_date - @clock_skew .. request_date + expires + @clock_skew).cover? @current_time
  end

  def get_algorithm_id
    @algo_prefix + '-HMAC-' + @hash_algo
  end

  def parse_algo(algorithm)
    m = /^#{@algo_prefix}-HMAC-(?<algo>[A-Z0-9\,]+)$/.match(algorithm)
    m && m['algo']
  end

  def calculate_signing_key(api_secret)
    algo = create_algo
    signing_key = @algo_prefix + api_secret
    key_parts = [short_date(@current_time)] + @credential_scope.split('/')
    key_parts.each { |data|
      signing_key = Digest::HMAC.digest(data, signing_key, algo)
    }
    signing_key
  end

  def canonicalize_path(path)
    while path.gsub!(%r{([^/]+)/\.\./?}) { |match| $1 == '..' ? match : '' } do end
    path.gsub(%r{/\./}, '/').sub(%r{/\.\z}, '/').gsub(/\/+/, '/')
  end

  def canonicalize_headers(raw_headers, headers_to_sign)
    collect_headers(raw_headers)
      .sort
      .select { |k, v| headers_to_sign.include?(k) }
      .map { |k, v| k + ':' + v.map { |piece| normalize_white_spaces piece} .join(',') }
  end

  def normalize_white_spaces(value)
    value.strip.split('"', -1).map.with_index { |piece, index|
      is_inside_of_quotes = (index % 2 === 1)
      is_inside_of_quotes ? piece : piece.gsub(/\s+/, ' ')
    }.join '"'
  end

  def collect_headers(raw_headers)
    headers = {}
    raw_headers.each do |raw_header|
      if raw_header[0].downcase != @auth_header_name.downcase
        if headers[raw_header[0].downcase]
          headers[raw_header[0].downcase] << raw_header[1]
        else
          headers[raw_header[0].downcase] = [raw_header[1]]
        end
      end
    end
    headers
  end

  def canonicalize_query(query_parts)
    query_parts
      .map { |k, v| uri_encode(k.gsub('+', ' ')) + '=' + uri_encode(v || '') }
      .sort.join '&'
  end

  def uri_encode(component)
    Addressable::URI.encode_component(component, Addressable::URI::CharacterClasses::UNRESERVED)
  end

  def uri_decode(component)
    Addressable::URI.unencode_component(component)
  end
end

class EscherRequest

  def initialize(request)
    @request = request
    @request_uri = Addressable::URI.parse(uri)
    prepare_request_headers()
  end

  def prepare_request_headers
    @request_headers = []
    case @request.class.to_s
      when "Hash"
        @request_headers = @request[:headers]
      when "Sinatra::Request" # TODO: not working yet
        @request.env.each { |key, value|
          if key.downcase[0, 5] == "http_"
            @request_headers += [[ key[5..-1].gsub("_", "-"), value ]]
          end
        }
      when "WEBrick::HTTPRequest"
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

  def setHeader(key, value)
    @request[key] = value
  end

  def method
    case @request.class.to_s
      when "Hash"
        @request[:method]
      else
        @request.request_method
    end
  end

  def uri
    case @request.class.to_s
      when "Hash"
        @request[:uri]
      else
        @request.uri
    end
  end

  def body
    case @request.class.to_s
      when "Hash"
        @request[:body]
      else
        @request.body
    end
  end

  def host
    @request_uri.host
  end

  def path
    @request_uri.path
  end

  def query_values
    @request_uri.query_values(Array) || []
  end

end

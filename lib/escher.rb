require "escher/version"

require 'time'
require 'uri'
require 'digest'
require 'pathname'
require 'addressable/uri'

class EscherError < RuntimeError
end

class Escher

  def initialize(options)
    @vendor_prefix    = options[:vendor_prefix]    || 'Escher'
    @hash_algo        = options[:hash_algo]        || 'SHA256'
    @current_time     = options[:current_time]     || Time.now()
    @credential_scope = options[:credential_scope] || 'us-east-1/host/aws4_request'
    @auth_header_name = options[:auth_header_name] || 'X-Escher-Auth'
    @date_header_name = options[:date_header_name] || 'X-Escher-Date'
  end

  def validate_request(method, request_uri, body, headers, key_db)
    host = get_header('host', headers) # TODO: Indirect validation if the host header is missing
    date = Time.parse(get_header(@date_header_name, headers))
    auth_header = get_header(@auth_header_name, headers)

    algo, api_key_id, short_date, credential_scope, signed_headers, signature = parse_auth_header(auth_header)

    escher = Escher.new(
      vendor_prefix: @vendor_prefix,
      hash_algo: algo,
      auth_header_name: @auth_header_name,
      date_header_name: @date_header_name,
      credential_scope: credential_scope,
      current_time: date,
    )

    raise EscherError, 'Host header is not signed' unless signed_headers.include? 'host'
    raise EscherError, 'Date header is not signed' unless signed_headers.include? @date_header_name.downcase
    raise EscherError, 'Invalid request date' unless short_date(date) == short_date && is_date_within_range?(date)
    # TODO validate host header
    raise EscherError, 'Invalid credentials' unless credential_scope == @credential_scope

    api_secret = key_db[api_key_id]

    path, query_parts = parse_uri(request_uri)
    expected_signature = escher.generate_signature(api_secret, body, headers, method, signed_headers, path, query_parts)
    raise EscherError, 'The signatures do not match' unless signature == expected_signature
  end

  # TODO: do we really need host here?
  def generate_auth_header(client, method, host, request_uri, body, headers, headers_to_sign)
    path, query_parts = parse_uri(request_uri)
    headers = add_defaults_to(headers, host, @current_time.utc.rfc2822)
    headers_to_sign |= [@date_header_name.downcase, 'host']
    signature = generate_signature(client[:api_secret], body, headers, method, headers_to_sign, path, query_parts)
    "#{get_algorithm_id} Credential=#{client[:api_key_id]}/#{short_date(@current_time)}/#{@credential_scope}, SignedHeaders=#{headers_to_sign.uniq.join ';'}, Signature=#{signature}"
  end

  def generate_signed_url(url_to_sign, client, expires = 86400)
    uri = URI.parse(url_to_sign)
    protocol = uri.scheme
    host = uri.host
    path = uri.path
    query_parts = parse_query(uri.query)

    headers = [['host', host]]
    headers_to_sign = ['host']
    body = 'UNSIGNED-PAYLOAD'
    query_parts += get_signing_params(client, expires, headers_to_sign)

    signature = generate_signature(client[:api_secret], body, headers, 'GET', headers_to_sign, path, query_parts)
    query_parts_with_signature = (query_parts.map { |k, v| [k, URI_encode(v)] } << query_pair('Signature', signature))

    protocol + '://' + host + path + '?' + query_parts_with_signature.map { |k, v| k + '=' + v }.join('&')
  end

  # TODO: rename to validate_presigned_url
  def validate_signed_url(presigned_url, client)
    uri = URI.parse(presigned_url)
    host = uri.host
    path = uri.path
    query_parts = parse_query(uri.query)
    headers = [['host', host]]
    headers_to_sign = ['host']
    body = 'UNSIGNED-PAYLOAD'
    signature, signing_params, query_parts = extract_signing_params(query_parts)

    client_api_key_id, short_date, credential_scope = signing_params['credentials'].split('/', 3)
    signed_headers = signing_params['signedheaders']
    date = Time.parse(signing_params['date'])
    expires = signing_params['expires'].to_i
    algorithm = process_algorithm_id(signing_params['algorithm'])

    raise EscherError, 'Invalid API key' unless client_api_key_id == client[:api_key_id]
    raise EscherError, 'Only SHA256 and SHA512 hash algorithms are allowed' unless ['sha256', 'sha512'].include?(algorithm)
    raise EscherError, 'The host header is not signed' unless signed_headers.split(';').include? 'host'
    raise EscherError, 'Only the host header should be signed' unless signed_headers == 'host'
    raise EscherError, 'The credential date does not match with the request date' unless short_date(date) == short_date
    raise EscherError, 'The request date is not within the accepted time range' unless is_date_not_expired?(date, expires)
    raise EscherError, 'Invalid credentials' unless credential_scope == @credential_scope

    expected_signature = generate_signature(client[:api_secret], body, headers, 'GET', headers_to_sign, path, query_parts)
    raise EscherError, 'The signatures do not match' unless signature == expected_signature

    true
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

  def extract_signing_params(query_parts)
    signature = nil
    signing_params = {}
    query_parts_filtered = []
    headers = ['algorithm', 'credentials', 'date', 'expires', 'signedheaders']
    query_parts.each { |k, v|
      knorm = query_key_truncate(k.downcase)
      v = URI_decode(v)
      if knorm == 'signature'
        signature = v
      else
        if headers.include?(knorm)
          signing_params[knorm] = v
        end
        query_parts_filtered += [[k, v]]
      end
    }
    [signature, signing_params, query_parts_filtered]
  end

  def query_pair(k, v)
    [query_key_for(k), URI::encode(v)]
  end

  def query_key_for(key)
    "X-#{@vendor_prefix}-#{key}"
  end

  def query_key_truncate(key)
    key[@vendor_prefix.length + 3..-1]
  end

  def get_header(header_name, headers)
    header = (headers.detect { |header| header[0].downcase == header_name.downcase })
    raise EscherError, "Missing header: #{header_name.downcase}" unless header
    header[1]
  end

  def parse_auth_header(auth_header)
    m = /#{@vendor_prefix.upcase}-HMAC-(?<algo>[A-Z0-9\,]+) Credential=(?<api_key_id>[A-Za-z0-9\-_]+)\/(?<short_date>[0-9]{8})\/(?<credentials>[A-Za-z0-9\-_\/]+), SignedHeaders=(?<signed_headers>[A-Za-z\-;]+), Signature=(?<signature>[0-9a-f]+)$/
    .match auth_header
    raise EscherError, 'Malformed authorization header' unless m && m['credentials']
    [
        m['algo'],
        m['api_key_id'],
        m['short_date'],
        m['credentials'],
        m['signed_headers'].split(';'),
        m['signature'],
    ]
  end

  # TODO: remove unused params
  def generate_signature(api_secret, body, headers, method, signed_headers, path, query_parts)
    canonicalized_request = canonicalize(method, path, query_parts, body, headers, signed_headers.uniq)
    string_to_sign = get_string_to_sign(canonicalized_request)
    signing_key = calculate_signing_key(api_secret)
    Digest::HMAC.hexdigest(string_to_sign, signing_key, create_algo)
  end

  def add_defaults_to(headers, host, date)
    [['host', host], [@date_header_name, date]].each { |k, v| headers = add_if_missing headers, k, v }
    headers
  end

  def add_if_missing(headers, header_to_find, value)
    headers += [header_to_find, value] unless headers.find { |header| k, v = header; k.downcase == header_to_find.downcase }
    headers
  end

  def canonicalize(method, path, query_parts, body, headers, headers_to_sign)
    [
      method.upcase,
      canonicalize_path(path),
      canonicalize_query(query_parts),
      canonicalize_headers(headers, @auth_header_name).join("\n"),
      '',
      headers_to_sign.uniq.join(';'),
      request_body_hash(body)
    ].join "\n"
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

  def create_algo()
    case @hash_algo.upcase
      when 'SHA256'
        return Digest::SHA256
      when 'SHA512'
        return Digest::SHA512
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

  def is_date_within_range?(date)
    (@current_time - 900 .. @current_time + 900).cover?(date)
  end

  def is_date_not_expired?(date, expires)
    # TODO: check the docs for the FROM part
    (@current_time .. @current_time + expires).cover?(date)
  end

  def get_algorithm_id
    @vendor_prefix + '-HMAC-' + @hash_algo
  end

  def process_algorithm_id(algorithm)
    m = /^#{@vendor_prefix.upcase}-HMAC-(?<algo>[A-Z0-9\,]+)$/.match(algorithm)
    m && m['algo'].downcase
  end

  def calculate_signing_key(api_secret)
    signing_key = @vendor_prefix + api_secret
    for data in [short_date(@current_time)] + @credential_scope.split('/') do
      signing_key = Digest::HMAC.digest(data, signing_key, create_algo)
    end
    signing_key
  end

  def canonicalize_path(path)
    while path.gsub!(%r{([^/]+)/\.\./?}) { |match| $1 == '..' ? match : '' } do end
    path.gsub(%r{/\./}, '/').sub(%r{/\.\z}, '/').gsub(/\/+/, '/')
  end

  def canonicalize_headers(raw_headers, auth_header_name)
    collect_headers(raw_headers, @auth_header_name)
      .sort
      .map { |k, v| k + ':' + (v.sort_by { |x| x }).join(',').gsub(/\s+/, ' ').strip }
  end

  def collect_headers(raw_headers, auth_header_name)
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

  def request_body_hash(body)
    create_algo.new.hexdigest(body)
  end

  def canonicalize_query(query_parts)
    query_parts
      .map { |k, v| URI_encode(k.gsub('+', ' ')) + '=' + URI_encode(v || '') }
      .sort.join '&'
  end

  def URI_encode(component)
    Addressable::URI.encode_component(component, Addressable::URI::CharacterClasses::UNRESERVED)
  end

  def URI_decode(component)
    Addressable::URI.unencode_component(component)
  end
end

require "escher/version"

require 'time'
require 'uri'
require 'digest'
require 'addressable/uri'

class EscherError < RuntimeError
end

class Escher
  def self.default_options
    {:auth_header_name => 'X-Escher-Auth', :date_header_name => 'X-Escher-Date', :vendor_prefix => 'Escher'}
  end

  def self.validate_request(method, request_uri, body, headers, key_db, accepted_credentials, current_time = Time.now, options = {})

    options = default_options.merge(options)
    host = get_header('host', headers)
    date = get_header(options[:date_header_name], headers)
    auth_header = get_header(options[:auth_header_name], headers)

    algo, api_key_id, short_date, credential_scope, signed_headers, signature = parse_auth_header auth_header, options[:vendor_prefix]

    raise EscherError, 'Host header is not signed' unless signed_headers.include? 'host'
    raise EscherError, 'Date header is not signed' unless signed_headers.include? options[:date_header_name].downcase
    raise EscherError, 'Invalid request date' unless short_date(date) == short_date && within_range(current_time, date)
    # TODO validate host header
    raise EscherError, 'Invalid credentials' unless credential_scope == accepted_credentials

    api_secret = key_db[api_key_id]

    path, query_parts = parse_uri request_uri
    signature == generate_signature(algo, api_secret, body, credential_scope.join('/'), date, headers, method, signed_headers, host, path, query_parts, options[:vendor_prefix], options[:auth_header_name], options[:date_header_name])
  end

  def self.generate_auth_header(client, method, host, request_uri, body, headers, headers_to_sign, date = Time.now.utc.rfc2822, algo = 'SHA256', options = {})
    options = default_options.merge options
    path, query_parts = parse_uri(request_uri)
    headers = add_defaults_to headers, host, date, options[:date_header_name]
    headers_to_sign |= [options[:date_header_name].downcase, 'host']
    signature = generate_signature(algo, client[:api_secret], body, credential_scope_as_string(client), date, headers, method, headers_to_sign, host, path, query_parts, options[:vendor_prefix], options[:auth_header_name], options[:date_header_name])
    "#{algo_id(options[:vendor_prefix], algo)} Credential=#{client[:api_key_id]}/#{short_date(date)}/#{credential_scope_as_string(client)}, SignedHeaders=#{headers_to_sign.uniq.join ';'}, Signature=#{signature}"
  end

  def self.generate_signed_url(client, protocol, host, request_uri, date = Time.now.utc.rfc2822, expires = 86400, algo = 'SHA256', options = {})
    options = default_options.merge options
    path, query_parts = parse_uri(request_uri)
    headers = [['host', host]]
    headers_to_sign = ['host']
    body = 'UNSIGNED-PAYLOAD'
    scope_as_string = credential_scope_as_string(client)
    query_parts += signing_params(client, algo, date, expires, headers_to_sign, options, scope_as_string)
    signature = generate_signature(algo, client[:api_secret], body, scope_as_string, date, headers, 'GET', headers_to_sign, host, path, query_parts, options[:vendor_prefix], options[:auth_header_name], options[:date_header_name])

    query_parts_with_signature = (query_parts.map { |k, v| [k, URI_encode(v)] } << query_pair('Signature', signature, options[:vendor_prefix]))
    protocol + '://' + host + path + '?' + query_parts_with_signature.map { |k, v| k + '=' + v }.join('&')
  end

  def self.signing_params(client, algo, date, expires, headers_to_sign, options, scope_as_string)
    [
        ['Algorithm', "#{algo_id(options[:vendor_prefix], algo)}"],
        ['Credentials', "#{client[:api_key_id]}/#{short_date(date)}/#{scope_as_string}"],
        ['Date', long_date(date)],
        ['Expires', expires.to_s],
        ['SignedHeaders', headers_to_sign.join(';')],
    ].map { |k, v| query_pair(k, v, options[:vendor_prefix]) }
  end

  def self.query_pair(k, v, vendor_prefix)
    ["X-#{vendor_prefix}-#{k}", URI::encode(v)]
  end

  def self.query_key_for(key, vendor_prefix)
    "X-#{vendor_prefix}-#{key}"
  end

  def self.short_date(date)
    long_date(date)[0..7]
  end

  def self.within_range(current_time, date)
    (current_time - 900 .. current_time + 900).cover?(Time.parse date)
  end

  def self.get_header(header_name, headers)
    header = (headers.detect { |header| header[0].downcase == header_name.downcase })
    raise EscherError, "Missing header: #{header_name.downcase}" unless header
    header[1]
  end

  def self.parse_auth_header(auth_header, vendor_prefix)
    m = /#{vendor_prefix.upcase}-HMAC-(?<algo>[A-Z0-9\,]+) Credential=(?<api_key_id>[A-Za-z0-9\-_]+)\/(?<short_date>[0-9]{8})\/(?<credentials>[A-Za-z0-9\-_\/]+), SignedHeaders=(?<signed_headers>[A-Za-z\-;]+), Signature=(?<signature>[0-9a-f]+)$/
    .match auth_header
    raise EscherError, 'Malformed authorization header' unless m && m['credentials']
    [
        m['algo'],
        m['api_key_id'],
        m['short_date'],
        m['credentials'].split('/'),
        m['signed_headers'].split(';'),
        m['signature'],
    ]
  end

  def self.credential_scope_as_string(client)
    client[:credential_scope].join '/'
  end

  def self.generate_signature(algo, api_secret, body, credential_scope, date, headers, method, signed_headers, host, path, query_parts, vendor_prefix, auth_header_name, date_header_name)
    canonicalized_request = canonicalize method, path, query_parts, body, headers, signed_headers.uniq, algo, auth_header_name
    string_to_sign = get_string_to_sign credential_scope, canonicalized_request, date, vendor_prefix, algo
    signing_key = calculate_signing_key api_secret, date, vendor_prefix, credential_scope, algo
    calculate_signature algo, signing_key, string_to_sign
  end

  def self.add_defaults_to(headers, host, date, date_header_name)
    [['host', host], [date_header_name, date]].each { |k, v| headers = add_if_missing headers, k, v }
    headers
  end

  def self.add_if_missing(headers, header_to_find, value)
    headers += [header_to_find, value] unless headers.find { |header| k, v = header; k.downcase == header_to_find.downcase }
    headers
  end

  def self.calculate_signature(algo, signing_key, string_to_sign)
    Digest::HMAC.hexdigest(string_to_sign, signing_key, create_algo(algo))
  end

  def self.canonicalize(method, path, query_parts, body, headers, headers_to_sign, algo, auth_header_name)
    ([
        method.upcase,
        canonicalize_path(path),
        canonicalize_query(query_parts),
    ] + canonicalize_headers(headers, auth_header_name) + [
        '',
        headers_to_sign.uniq.join(';'),
        request_body_hash(body, algo)
    ]).join "\n"
  end

  def self.parse_uri(request_uri)
    path, query = request_uri.split '?', 2
    return path, parse_query(query)
  end

  def self.parse_query(query)
    (query || '')
    .split('&', -1)
    .map { |pair| pair.split('=', -1) }
    .map { |k, v| (k.include?' ') ? [k.str(/\S+/), ''] : [k, v] }
  end

  def self.get_string_to_sign(credential_scope, canonicalized_req, date, prefix, algo)
    date = long_date(date)
    lines = [
        algo_id(prefix, algo),
        date,
        date[0..7] + '/' + credential_scope,
        create_algo(algo).new.hexdigest(canonicalized_req)
    ]
    lines.join "\n"
  end

  def self.create_algo(algo)
    case algo.upcase
      when 'SHA256'
        return Digest::SHA256
      when 'SHA512'
        return Digest::SHA512
      else
        raise EscherError, 'Unidentified hash algorithm'
    end
  end

  def self.long_date(date)
    Time.parse(date).utc.strftime('%Y%m%dT%H%M%SZ')
  end

  def self.algo_id(prefix, algo)
    prefix + '-HMAC-' + algo
  end

  def self.calculate_signing_key(api_secret, date, vendor_prefix, credential_scope, algo)
    signing_key = vendor_prefix + api_secret
    for data in [short_date(date)] + credential_scope.split('/') do
      signing_key = Digest::HMAC.digest(data, signing_key, create_algo(algo))
    end
    signing_key
  end

  def self.canonicalize_path(path)
    while path.gsub!(%r{([^/]+)/\.\./?}) { |match| $1 == '..' ? match : '' } do end
    path.gsub(%r{/\./}, '/').sub(%r{/\.\z}, '/').gsub(/\/+/, '/')
  end

  def self.canonicalize_headers(raw_headers, auth_header_name)
    collect_headers(raw_headers, auth_header_name)
      .sort
      .map { |k, v| k + ':' + (v.sort_by { |x| x }).join(',').gsub(/\s+/, ' ').strip }
  end

  def self.collect_headers(raw_headers, auth_header_name)
    headers = {}
    raw_headers.each do |raw_header|
      if raw_header[0].downcase != auth_header_name.downcase
        if headers[raw_header[0].downcase]
          headers[raw_header[0].downcase] << raw_header[1]
        else
          headers[raw_header[0].downcase] = [raw_header[1]]
        end
      end
    end
    headers
  end

  def self.request_body_hash(body, algo)
    create_algo(algo).new.hexdigest body
  end

  def self.canonicalize_query(query_parts)
    query_parts
      .map { |k, v| URI_encode(k.gsub('+', ' ')) + '=' + URI_encode(v || '') }
      .sort.join '&'
  end

  def self.URI_encode(component)
    Addressable::URI.encode_component(component, Addressable::URI::CharacterClasses::UNRESERVED)
  end
end

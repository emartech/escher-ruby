require 'time'
require 'uri'
require 'digest'

class EscherError < RuntimeError
end

module Escher
  VERSION = '0.0.1'

  def self.default_options
    {:auth_header_name => 'X-Ems-Auth', :date_header_name => 'X-Ems-Date', :vendor_prefix => 'EMS'}
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

    signature == generate_signature(algo, api_secret, body, credential_scope.join('/'), date, headers, method, signed_headers, host, request_uri, options[:vendor_prefix], options[:auth_header_name], options[:date_header_name])
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

  def self.generate_auth_header(client, method, host, request_uri, body, headers, headers_to_sign, date = Time.now.utc.rfc2822, algo = 'SHA256', options = {})
    options = default_options.merge options
    signature = generate_signature(algo, client[:api_secret], body, credential_scope_as_string(client), date, headers, method, headers_to_sign, host, request_uri, options[:vendor_prefix], options[:auth_header_name], options[:date_header_name])
    "#{algo_id(options[:vendor_prefix], algo)} Credential=#{client[:api_key_id]}/#{short_date(date)}/#{credential_scope_as_string(client)}, SignedHeaders=#{headers_to_sign.uniq.join ';'}, Signature=#{signature}"
  end

  def self.credential_scope_as_string(client)
    client[:credential_scope_as_string].join '/'
  end

  def self.generate_signature(algo, api_secret, body, credential_scope, date, headers, method, signed_headers, host, request_uri, vendor_prefix, auth_header_name, date_header_name)
    canonicalized_request = canonicalize method, host, request_uri, body, date, headers, signed_headers, algo, auth_header_name, date_header_name
    string_to_sign = get_string_to_sign credential_scope, canonicalized_request, date, vendor_prefix, algo
    signing_key = calculate_signing_key api_secret, date, vendor_prefix, credential_scope, algo
    calculate_signature algo, signing_key, string_to_sign
  end

  def self.calculate_signature(algo, signing_key, string_to_sign)
    Digest::HMAC.hexdigest(string_to_sign, signing_key, create_algo(algo))
  end

  def self.canonicalize(method, host, request_uri, body, date, headers, headers_to_sign, algo, auth_header_name, date_header_name)
    path, query = request_uri.split '?', 2

    ([
        method.upcase,
        canonicalize_path(path),
        canonicalize_query(query),
    ] + canonicalize_headers(date, host, headers, auth_header_name, date_header_name) + [
        '',
        (headers_to_sign | %w(date host)).join(';'),
        request_body_hash(body, algo)
    ]).join "\n"
  end

  # TODO: extract algo creation
  def self.get_string_to_sign(credential_scope, canonicalized_request, date, prefix, algo)
    date = long_date(date)
    lines = [
        algo_id(prefix, algo),
        date,
        date[0..7] + '/' + credential_scope,
        create_algo(algo).new.hexdigest(canonicalized_request)
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
    Time.parse(date).utc.strftime("%Y%m%dT%H%M%SZ")
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

  def self.canonicalize_headers(date, host, raw_headers, auth_header_name, date_header_name)
    collect_headers(raw_headers, auth_header_name).merge({date_header_name.downcase => [date], 'host' => [host]})
      .sort
      .map { |k, v| k + ':' + (v.sort_by { |x| x }).join(',').gsub(/\s+/, ' ').strip }
  end

  def self.collect_headers(raw_headers, auth_header_name)
    headers = {}
    raw_headers.each { |raw_header|
      if raw_header[0].downcase != auth_header_name.downcase then
        if headers[raw_header[0].downcase] then
          headers[raw_header[0].downcase] << raw_header[1]
        else
          headers[raw_header[0].downcase] = [raw_header[1]]
        end
      end
    }
    headers
  end

  def self.request_body_hash(body, algo)
    create_algo(algo).new.hexdigest body
  end

  def self.canonicalize_query(query)
    query = query || ''
    query.split('&', -1)
    .map { |pair| k, v = pair.split('=', -1)
    if k.include? ' ' then
      [k.str(/\S+/), '']
    else
      [k, v]
    end }
    .map { |pair|
      k, v = pair;
      URI::encode(k.gsub('+', ' ')) + '=' + URI::encode(v || '')
    }
    .sort.join '&'
  end
end

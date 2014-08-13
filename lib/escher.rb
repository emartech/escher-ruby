require 'time'
require 'uri'
require 'digest'

class Escher
  VERSION = '0.0.1'

  def validate_request(method, url, body, headers, auth_header_name, date_header_name, vendor_prefix)
    auth_header = get_header(auth_header_name, headers)
    date = get_header(date_header_name, headers)

    algo, api_key_id, short_date, credential_scope, signed_headers, signature = parse_auth_header auth_header, vendor_prefix

    api_secret = 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY'

    signature == expected_signature(algo, api_secret, body, credential_scope, date, headers, method, signed_headers, url, vendor_prefix, auth_header_name)
  end

  def expected_signature(algo, api_secret, body, credential_scope, date, headers, method, signed_headers, url, vendor_prefix, auth_header_name)
    generate_signature(algo, api_secret, body, credential_scope, date, headers, method, signed_headers, url, vendor_prefix, auth_header_name)
  end

  def get_header(header_name, headers)
    (headers.detect { |header| header[0].downcase == header_name.downcase })[1]
  end

  def parse_auth_header(auth_header, vendor_prefix)
    m = /#{vendor_prefix.upcase}-HMAC-(?<algo>[A-Z0-9\,]+) Credential=(?<credentials>[A-Za-z0-9\/\-_]+), SignedHeaders=(?<signed_headers>[A-Za-z\-;]+), Signature=(?<signature>[0-9a-f]+)$/
      .match auth_header
    [
        m['algo'],
    ] + m['credentials'].split('/', 3) + [
        m['signed_headers'].split(';'),
        m['signature'],
    ]
  end

  def get_auth_header(auth_header_name, vendor_prefix, algo, api_key_id, api_secret, date, credential_scope, method, url, body, headers, signed_headers)
    signature = generate_signature(algo, api_secret, body, credential_scope, date, headers, method, signed_headers, url, vendor_prefix, auth_header_name)
    "#{algo_id(vendor_prefix, algo)} Credential=#{api_key_id}/#{long_date(date)[0..7]}/#{credential_scope}, SignedHeaders=#{signed_headers.uniq.join ';'}, Signature=#{signature}"
  end

  def generate_signature(algo, api_secret, body, credential_scope, date, headers, method, signed_headers, url, vendor_prefix, auth_header_name)
    canonicalized_request = canonicalize method, url, body, date, headers, signed_headers, algo, auth_header_name
    string_to_sign = get_string_to_sign credential_scope, canonicalized_request, date, vendor_prefix, algo
    signing_key = calculate_signing_key(api_secret, date, vendor_prefix, credential_scope, algo)
    signature = calculate_signature(algo, signing_key, string_to_sign)
  end

  def calculate_signature(algo, signing_key, string_to_sign)
    Digest::HMAC.hexdigest(string_to_sign, signing_key, create_algo(algo))
  end

  def canonicalize(method, url, body, date, headers, headers_to_sign, algo, auth_header_name)
    url, query = url.split '?', 2 # URI#parse cannot parse unicode characters in query string TODO use Adressable
    uri = URI.parse(url)

    ([
        method.upcase,
        canonicalize_path(uri),
        canonicalize_query(query),
    ] + canonicalize_headers(date, uri, headers, auth_header_name) + [
        '',
        (headers_to_sign | %w(date host)).join(';'),
        request_body_hash(body, algo)
    ]).join "\n"
  end

  # TODO: extract algo creation
  def get_string_to_sign(credential_scope, canonicalized_request, date, prefix, algo)
    date = long_date(date)
    lines = [
        algo_id(prefix, algo),
        date,
        date[0..7] + '/' + credential_scope,
        create_algo(algo).new.hexdigest(canonicalized_request)
    ]
    lines.join "\n"
  end

  def create_algo(algo)
    case algo.upcase
      when 'SHA256'
        return Digest::SHA256
      when 'SHA512'
        return Digest::SHA512
      else
        raise('Unidentified hash algorithm')
    end
  end

  def long_date(date)
    Time.parse(date).utc.strftime("%Y%m%dT%H%M%SZ")
  end

  def algo_id(prefix, algo)
    prefix + '-HMAC-' + algo
  end

  def calculate_signing_key(api_secret, date, vendor_prefix, credential_scope, algo)
    signing_key = vendor_prefix + api_secret
    for data in [long_date(date)[0..7]] + credential_scope.split('/') do
      signing_key = Digest::HMAC.digest(data, signing_key, create_algo(algo))
    end
    signing_key
  end

  def canonicalize_path(uri)
    path = uri.path
    while path.gsub!(%r{([^/]+)/\.\./?}) { |match|
      $1 == '..' ? match : ''
    } do
    end
      path = path.gsub(%r{/\./}, '/').sub(%r{/\.\z}, '/').gsub(/\/+/, '/')
    end

    def canonicalize_headers(date, uri, raw_headers, auth_header_name)
      collect_headers(raw_headers, auth_header_name).merge({'date' => [date], 'host' => [uri.host]}).map { |k, v| k + ':' + (v.sort_by { |x| x }).join(',').gsub(/\s+/, ' ').strip }
    end

    def collect_headers(raw_headers, auth_header_name)
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

    def request_body_hash(body, algo)
      create_algo(algo).new.hexdigest body
    end

    def canonicalize_query(query)
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

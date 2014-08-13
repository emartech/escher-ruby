require 'time'
require 'uri'
require 'digest'

class Escher
  VERSION = '0.0.1'

  def canonicalize(method, url, body, date, headers, headers_to_sign = [], algo = 'SHA256')

    url, query = url.split '?', 2 # URI#parse cannot parse unicode characters in query string TODO use Adressable
    uri = URI.parse(url)

    ([
        method,
        canonicalize_path(uri),
        canonicalize_query(query),
    ] + canonicalize_headers(date, uri, headers) + [
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

  def get_auth_header(header_name, vendor_prefix, algo, api_key_id, api_secret, date, credential_scope, method, url, body, headers, signed_headers)
    canonicalized_request = canonicalize method, url, body, date, headers, signed_headers
    string_to_sign = get_string_to_sign credential_scope, canonicalized_request, date, vendor_prefix, algo
    signing_key = calculate_signing_key(api_secret, date, vendor_prefix, credential_scope, algo)

    signature = Digest::HMAC.hexdigest(string_to_sign, signing_key, create_algo(algo))
    "#{algo_id(vendor_prefix, algo)} Credential=#{api_key_id}/#{long_date(date)[0..7]}/#{credential_scope}, SignedHeaders=#{signed_headers.uniq.join ';'}, Signature=#{signature}"
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

    def canonicalize_headers(date, uri, raw_headers)
      collect_headers(raw_headers).merge({'date' => [date], 'host' => [uri.host]}).map { |k, v| k + ':' + (v.sort_by { |x| x }).join(',').gsub(/\s+/, ' ').strip }
    end

    def collect_headers(raw_headers)
      headers = {}
      raw_headers.each { |raw_header|
        if headers[raw_header[0].downcase] then
          headers[raw_header[0].downcase] << raw_header[1]
        else
          headers[raw_header[0].downcase] = [raw_header[1]]
        end }
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

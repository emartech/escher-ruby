require 'uri'
require 'pp'
require 'digest'

class Escher
  VERSION = '0.0.1'

  def canonicalize(method, url, body, date, headers, headers_to_sign = [])
    uri = URI.parse(url)

    ([
        method,
        canonicalized_path(uri),
        canonicalized_query(uri),
    ] + canonicalized_headers(date, uri, headers) + [
        '',
        (headers_to_sign | %w(date host)).join(';'),
        request_body_hash(body)
    ]).join "\n"
  end

  def canonicalized_path(uri)
    path = uri.path
    while path.gsub!(%r{([^/]+)/\.\./?}) { |match|
      $1 == '..' ? match : ''
    } do
    end
      path = path.gsub(%r{/\./}, '/').sub(%r{/\.\z}, '/').gsub(/\/+/, '/')
    end

    def canonicalized_headers(date, uri, raw_headers)
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

    def request_body_hash(body)
      Digest::SHA256.new.hexdigest body
    end

    def canonicalized_query(uri)
      query = uri.query ? uri.query : ''
      query.split('&', -1)
      .map { |pair| k, v = pair.split('=', -1)
      if k.include? ' ' then
        [k.str(/\S+/), '']
      else
        [k, v]
      end }
      .map { |pair| k, v = pair; URI::encode(k) + '=' + URI::encode(v) }
      .sort.join '&'
    end
  end

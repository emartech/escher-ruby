require 'uri'
require 'pp'
require 'digest'

class Escher
  VERSION = '0.0.1'

  def canonicalize(method, url, body, date, headers, headers_to_sign = [])
    uri = URI.parse(url)

    ([
        method,
        uri.path,
        query(uri),
    ] + canonicalized_headers(date, uri, headers) + [
        '',
        (headers_to_sign | %w(date host)).join(';'),
        request_body_hash(body)
    ]).join "\n"
  end

  def canonicalized_headers(date, uri, headers)
    headers.merge({'Date' => date, 'Host' => uri.host}).map {|k, v| k.downcase + ':' + v }
  end

  def request_body_hash(body)
    Digest::SHA256.new.hexdigest body
  end

  def query(uri)
    (uri.query ? uri.query : '')
  end
end

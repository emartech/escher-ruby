require 'uri'
require 'pp'
require 'digest'

class Escher
  VERSION = '0.0.1'

  def canonicalize(method, url, body, date, headers, headers_to_sign = [])
    headers_to_sign += %w(date host)
    uri = URI.parse(url)
    uri.scheme

    lines = [
        method,
        uri.path,
        query(uri),
    ] + canonicalized_headers(date, uri, headers) + [
        '',
        (headers_to_sign.join ';'),
        request_body_hash(body)
    ]
    lines.join "\n"
  end

  def canonicalized_headers(date, uri, headers)
    headers['date'] = date
    headers['host'] = uri.host
    headers.map {|k, v| k.downcase + ':' + v }
  end

  def request_body_hash(body)
    Digest::SHA256.new.hexdigest body
  end

  def query(uri)
    (uri.query ? uri.query : '')
  end
end

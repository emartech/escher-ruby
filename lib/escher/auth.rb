module Escher
  class Auth

    def initialize(credential_scope, options = {})
      @credential_scope = credential_scope
      @algo_prefix = options[:algo_prefix] || 'ESR'
      @vendor_key = options[:vendor_key] || 'Escher'
      @hash_algo = options[:hash_algo] || 'SHA256'
      @current_time = options[:current_time] || Time.now
      @auth_header_name = options[:auth_header_name] || 'X-Escher-Auth'
      @date_header_name = options[:date_header_name] || 'X-Escher-Date'
      @clock_skew = options[:clock_skew] || 300
      @algo = create_algo
      @algo_id = @algo_prefix + '-HMAC-' + @hash_algo
    end



    def sign!(req, client, headers_to_sign = [])
      headers_to_sign |= [@date_header_name.downcase, 'host']

      request = wrap_request req
      raise EscherError, 'The host header is missing' unless request.has_header? 'host'

      request.set_header(@date_header_name.downcase, format_date_for_header) unless request.has_header? @date_header_name

      signature = generate_signature(client[:api_secret], request.body, request.headers, request.method, headers_to_sign, request.path, request.query_values)
      request.set_header(@auth_header_name, "#{@algo_id} Credential=#{client[:api_key_id]}/#{short_date(@current_time)}/#{@credential_scope}, SignedHeaders=#{prepare_headers_to_sign headers_to_sign}, Signature=#{signature}")

      request.request
    end



    def is_valid?(*args)
      begin
        authenticate(*args)
        return true
      rescue
        return false
      end
    end



    def authenticate(req, key_db, mandatory_signed_headers = nil)
      request = wrap_request req
      method = request.method
      body = request.body
      headers = request.headers
      path = request.path
      query_parts = request.query_values

      signature_from_query = get_signing_param('Signature', query_parts)

      (['Host'] + (signature_from_query ? [] : [@auth_header_name, @date_header_name])).each do |header|
        raise EscherError, 'The ' + header.downcase + ' header is missing' unless request.header header
      end

      if method == 'GET' && signature_from_query
        raw_date = get_signing_param('Date', query_parts)
        algorithm, api_key_id, short_date, credential_scope, signed_headers, signature, expires = get_auth_parts_from_query(query_parts)

        body = 'UNSIGNED-PAYLOAD'
        query_parts.delete [query_key_for('Signature'), signature]
        query_parts = query_parts.map { |k, v| [k, v] }
      else
        raw_date = request.header @date_header_name
        raise EscherError, 'The ' + @date_header_name + ' header is missing' unless raw_date
        auth_header = request.header @auth_header_name
        raise EscherError, 'The ' + @auth_header_name + ' header is missing' unless raw_date
        algorithm, api_key_id, short_date, credential_scope, signed_headers, signature, expires = get_auth_parts_from_header(auth_header)
      end

      date = Time.parse(raw_date)
      api_secret = key_db[api_key_id]

      raise EscherError, 'Invalid Escher key' unless api_secret
      raise EscherError, 'Invalid hash algorithm, only SHA256 and SHA512 are allowed' unless %w(SHA256 SHA512).include?(algorithm)
      raise EscherError, 'The request method is invalid' unless valid_request_method?(method)
      raise EscherError, "The request body shouldn't be empty if the request method is POST" if (method.upcase == 'POST' && body.empty?)
      raise EscherError, "The request url shouldn't contains http or https" if path.match /^https?:\/\//
      raise EscherError, 'Invalid date in authorization header, it should equal with date header' unless short_date(date) == short_date
      raise EscherError, 'The request date is not within the accepted time range' unless is_date_within_range?(date, expires)
      raise EscherError, 'Invalid Credential Scope' unless credential_scope == @credential_scope
      raise EscherError, 'The mandatorySignedHeaders parameter must be undefined or array of strings' unless mandatory_signed_headers_valid?(mandatory_signed_headers)
      raise EscherError, 'The host header is not signed' unless signed_headers.include? 'host'
      unless mandatory_signed_headers.nil?
        mandatory_signed_headers.each do |header|
          raise EscherError, "The #{header} header is not signed" unless signed_headers.include? header
        end
      end
      raise EscherError, 'Only the host header should be signed' if signature_from_query && signed_headers != ['host']
      raise EscherError, 'The date header is not signed' if !signature_from_query && !signed_headers.include?(@date_header_name.downcase)

      escher = reconfig(algorithm, credential_scope, date)
      expected_signature = escher.generate_signature(api_secret, body, headers, method, signed_headers, path, query_parts)
      raise EscherError, 'The signatures do not match' unless signature == expected_signature
      api_key_id
    end



    def reconfig(algorithm, credential_scope, date)
      self.class.new(
        credential_scope,
        algo_prefix: @algo_prefix,
        vendor_key: @vendor_key,
        hash_algo: algorithm,
        auth_header_name: @auth_header_name,
        date_header_name: @date_header_name,
        current_time: date
      )
    end



    def generate_signed_url(url_to_sign, client, expires = 86400)
      uri = Addressable::URI.parse(url_to_sign)

      if (not uri.port.nil?) && (uri.port != uri.default_port)
        host = "#{uri.host}:#{uri.port}"
      else
        host = uri.host
      end

      path = uri.path
      query_parts = (uri.query || '')
      .split('&', -1)
      .map { |pair| pair.split('=', -1) }
      .map { |k, v| (k.include? ' ') ? [k.str(/\S+/), ''] : [k, v] }
      .map { |k, v| [uri_decode(k), uri_decode(v)] }
      fragment = uri.fragment

      headers = [['host', host]]
      headers_to_sign = ['host']
      body = 'UNSIGNED-PAYLOAD'
      query_parts += [
        ['Algorithm', @algo_id],
        ['Credentials', "#{client[:api_key_id]}/#{short_date(@current_time)}/#{@credential_scope}"],
        ['Date', long_date(@current_time)],
        ['Expires', expires.to_s],
        ['SignedHeaders', headers_to_sign.join(';')],
      ].map { |k, v| query_pair(k, v) }

      signature = generate_signature(client[:api_secret], body, headers, 'GET', headers_to_sign, path, query_parts)
      query_parts_with_signature = (query_parts.map { |k, v| [uri_encode(k), uri_encode(v)] } << query_pair('Signature', signature))
      "#{uri.scheme}://#{host}#{path}?#{query_parts_with_signature.map { |k, v| k + '=' + v }.join('&')}#{(fragment === nil ? '' : '#' + fragment)}"
    end



    def query_pair(k, v)
      [query_key_for(k), v]
    end



    def query_key_for(key)
      "X-#{@vendor_key}-#{key}"
    end



    def get_signing_param(key, query_parts)
      the_param = (query_parts.detect { |param| param[0] === query_key_for(key) })
      the_param ? uri_decode(the_param[1]) : nil
    end



    def get_auth_parts_from_header(auth_header)
      m = /#{@algo_prefix}-HMAC-(?<algo>[A-Z0-9\,]+) Credential=(?<api_key_id>[A-Za-z0-9\-_]+)\/(?<short_date>[0-9]{8})\/(?<credentials>[A-Za-z0-9\-_ \/]+), SignedHeaders=(?<signed_headers>[A-Za-z\-;]+), Signature=(?<signature>[0-9a-f]+)$/
      .match auth_header
      raise EscherError, 'Invalid auth header format' unless m && m['credentials']
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

      signing_key = OpenSSL::HMAC.digest(@algo, @algo_prefix + api_secret, short_date(@current_time))
      @credential_scope.split('/').each { |data|
        signing_key = OpenSSL::HMAC.digest(@algo, signing_key, data)
      }

      OpenSSL::HMAC.hexdigest(@algo, signing_key, string_to_sign)
    end



    def format_date_for_header
      @date_header_name.downcase == 'date' ? @current_time.utc.rfc2822.sub('-0000', 'GMT') : long_date(@current_time)
    end



    def canonicalize(method, path, query_parts, body, headers, headers_to_sign)
      [
        method,
        canonicalize_path(path),
        canonicalize_query(query_parts),
        canonicalize_headers(headers, headers_to_sign).join("\n"),
        '',
        prepare_headers_to_sign(headers_to_sign),
        @algo.new.hexdigest(body)
      ].join "\n"
    end



    def prepare_headers_to_sign(headers_to_sign)
      headers_to_sign.map(&:downcase).sort.uniq.join(';')
    end



    def parse_uri(request_uri)
      path, query = request_uri.split '?', 2
      return path, (query || '')
      .split('&', -1)
      .map { |pair| pair.split('=', -1) }
      .map { |k, v| (k.include? ' ') ? [k.str(/\S+/), ''] : [k, v] }
    end



    def get_string_to_sign(canonicalized_request)
      [
        @algo_id,
        long_date(@current_time),
        short_date(@current_time) + '/' + @credential_scope,
        @algo.new.hexdigest(canonicalized_request)
      ].join("\n")
    end



    def create_algo
      case @hash_algo
        when 'SHA256'
          @algo = OpenSSL::Digest::SHA256.new
        when 'SHA512'
          @algo = OpenSSL::Digest::SHA521.new
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



    def valid_request_method?(method)
      %w(OPTIONS GET HEAD POST PUT DELETE TRACE PATCH CONNECT).include? method.upcase
    end



    def mandatory_signed_headers_valid?(mandatory_signed_headers)
      if mandatory_signed_headers.nil?
        return true
      else
        return false unless mandatory_signed_headers.is_a? Array
        return false unless mandatory_signed_headers.all? { |header| header.is_a? String }
      end

      true
    end



    def parse_algo(algorithm)
      m = /^#{@algo_prefix}-HMAC-(?<algo>[A-Z0-9\,]+)$/.match(algorithm)
      m && m['algo']
    end



    def canonicalize_path(path)
      while path.gsub!(%r{([^/]+)/\.\./?}) { |match| $1 == '..' ? match : '' } do
      end
      path.gsub(%r{/\./}, '/').sub(%r{/\.\z}, '/').gsub(/\/+/, '/')
    end



    def canonicalize_headers(raw_headers, headers_to_sign)
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
      headers_to_sign.map!(&:downcase)
      headers
      .sort
      .select { |h| headers_to_sign.include?(h[0]) }
      .map { |k, v| k + ':' + v.map { |piece| normalize_white_spaces piece }.join(',') }
    end



    def normalize_white_spaces(value)
      value.strip.split('"', -1).map.with_index { |piece, index|
        is_inside_of_quotes = (index % 2 == 1)
        is_inside_of_quotes ? piece : piece.gsub(/\s+/, ' ')
      }.join '"'
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



    private

    def wrap_request(request)
      Escher::Request::Factory.from_request request
    end

  end
end

require 'spec_helper'

fixtures = %w(
  get-header-key-duplicate
  get-header-value-order
  get-header-value-trim
  get-relative get-relative-relative
  get-slash
  get-slash-dot-slash
  get-slash-pointless-dot
  get-slashes
  get-space
  get-unreserved
  get-utf8
  get-vanilla
  get-vanilla-empty-query-key
  get-vanilla-query
  get-vanilla-query-order-key
  get-vanilla-query-order-key-case
  get-vanilla-query-order-value
  get-vanilla-query-unreserved
  get-vanilla-ut8-query
  post-header-key-case
  post-header-key-sort
  post-header-value-case
  post-vanilla
  post-vanilla-empty-query-value
  post-vanilla-query
  post-vanilla-query-nonunreserved
  post-vanilla-query-space
  post-x-www-form-urlencoded
  post-x-www-form-urlencoded-parameters

)

ESCHER_AWS4_OPTIONS = {
  vendor_prefix: 'AWS4', hash_algo: 'SHA256', auth_header_name: 'Authorization', date_header_name: 'Date',
  credential_scope: 'us-east-1/host/aws4_request'
}

ESCHER_EMARSYS_OPTIONS = {
  vendor_prefix: 'EMS', hash_algo: 'SHA256', auth_header_name: 'Authorization', date_header_name: 'Date',
  credential_scope: 'us-east-1/host/aws4_request'
}

GOOD_AUTH_HEADER = 'AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20110909/us-east-1/host/aws4_request, SignedHeaders=date;host, Signature=b27ccfbfa7df52a200ff74193ca6e32d4b48b8856fab7ebf1c595d0670a7e470'

def key_db
  {'AKIDEXAMPLE' => 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY'}
end

def credential_scope
  %w(us-east-1 host aws4_request)
end

def client
  {:api_key_id => 'AKIDEXAMPLE', :api_secret => 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY', :credential_scope => credential_scope}
end

describe 'Escher' do
  fixtures.each do |test|
    it "should calculate canonicalized request for #{test}" do
      escher = Escher.new(ESCHER_AWS4_OPTIONS)
      method, request_uri, body, headers = read_request(test)
      headers_to_sign = headers.map {|k| k[0].downcase }
      path, query_parts = escher.parse_uri(request_uri)
      canonicalized_request = escher.canonicalize(method, path, query_parts, body, headers, headers_to_sign)
      check_canonicalized_request(canonicalized_request, test)
    end
  end

  fixtures.each do |test|
    it "should calculate string to sign for #{test}" do
      method, request_uri, body, headers, date = read_request(test)
      escher = Escher.new(ESCHER_AWS4_OPTIONS.merge(current_time: Time.parse(date)))
      headers_to_sign = headers.map {|k| k[0].downcase }
      path, query_parts = escher.parse_uri(request_uri)
      canonicalized_request = escher.canonicalize(method, path, query_parts, body, headers, headers_to_sign)
      string_to_sign = escher.get_string_to_sign(canonicalized_request)
      expect(string_to_sign).to eq(fixture(test, 'sts'))
    end
  end

  fixtures.each do |test|
    it "should calculate auth header for #{test}" do
      method, request_uri, body, headers, date, host = read_request(test)
      escher = Escher.new(ESCHER_AWS4_OPTIONS.merge(current_time: Time.parse(date)))
      headers_to_sign = headers.map {|k| k[0].downcase }
      auth_header = escher.generate_auth_header(client, method, host, request_uri, body, headers, headers_to_sign)
      expect(auth_header).to eq(fixture(test, 'authz'))
    end
  end

  it 'should generate signed url' do
    escher = Escher.new(ESCHER_EMARSYS_OPTIONS.merge(current_time: Time.parse('2011/05/11 12:00:00 UTC')))
    expected_url =
        'http://example.com/something?foo=bar&' + 'baz=barbaz&' +
            'X-EMS-Algorithm=EMS-HMAC-SHA256&' +
            'X-EMS-Credentials=th3K3y%2F20110511%2Fus-east-1%2Fhost%2Faws4_request&' +
            'X-EMS-Date=20110511T120000Z&' +
            'X-EMS-Expires=123456&' +
            'X-EMS-SignedHeaders=host&' +
            'X-EMS-Signature=fbc9dbb91670e84d04ad2ae7505f4f52ab3ff9e192b8233feeae57e9022c2b67'

    client = {:api_key_id => 'th3K3y', :api_secret => 'very_secure', :credential_scope =>  %w(us-east-1 host aws4_request)}
    expect(escher.generate_signed_url(client, 'http', 'example.com', '/something?foo=bar&baz=barbaz', 123456)).to eq expected_url
  end

  it 'should validate request' do
    headers = [
        ['Host', 'host.foo.com'],
        ['Date', 'Mon, 09 Sep 2011 23:36:00 GMT'],
        ['Authorization', GOOD_AUTH_HEADER],
    ]
    expect { call_validate_request(headers) }.not_to raise_error
  end

  it 'should detect if signatures do not match' do
    headers = [
        ['Host', 'host.foo.com'],
        ['Date', 'Mon, 09 Sep 2011 23:36:00 GMT'],
        ['Authorization', 'AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20110909/us-east-1/host/aws4_request, SignedHeaders=date;host, Signature=ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'],
    ]
    expect { call_validate_request(headers) }.to raise_error(EscherError, 'The signatures do not match')
  end

  it 'should detect if dates are not on the same day' do
    yesterday = '08'
    headers = [
        ['Host', 'host.foo.com'],
        ['Date', "Mon, #{yesterday} Sep 2011 23:36:00 GMT"],
        ['Authorization', GOOD_AUTH_HEADER],
    ]
    expect { call_validate_request(headers) }.to raise_error(EscherError, 'Invalid request date')
  end

  it 'should detect if date is not within the 15 minutes range' do
    long_ago = '00'
    headers = [
        ['Host', 'host.foo.com'],
        ['Date', "Mon, 09 Sep 2011 23:#{long_ago}:00 GMT"],
        ['Authorization', GOOD_AUTH_HEADER],
    ]
    expect { call_validate_request(headers) }.to raise_error(EscherError, 'Invalid request date')
  end

  it 'should detect missing host header' do
    headers = [
        ['Date', "Mon, 09 Sep 2011 23:36:00 GMT"],
        ['Authorization', GOOD_AUTH_HEADER],
    ]
    expect { call_validate_request(headers) }.to raise_error(EscherError, 'Missing header: host')
  end

  it 'should detect missing date header' do
    headers = [
        ['Host', 'host.foo.com'],
        ['Authorization', GOOD_AUTH_HEADER],
    ]
    expect { call_validate_request(headers) }.to raise_error(EscherError, 'Missing header: date')
  end

  it 'should detect missing auth header' do
    headers = [
        ['Host', 'host.foo.com'],
        ['Date', "Mon, 09 Sep 2011 23:36:00 GMT"],
    ]
    expect { call_validate_request(headers) }.to raise_error(EscherError, 'Missing header: authorization')
  end

  it 'should detect malformed auth header' do
    headers = [
        ['Host', 'host.foo.com'],
        ['Date', "Mon, 09 Sep 2011 23:36:00 GMT"],
        ['Authorization', 'AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20110909/us-east-1/host/aws4_request, SignedHeaders=date;host, Signature=UNPARSABLE'],
    ]
    expect { call_validate_request(headers) }.to raise_error(EscherError, 'Malformed authorization header')
  end

  it 'should detect malformed credential scope' do
    headers = [
        ['Host', 'host.foo.com'],
        ['Date', "Mon, 09 Sep 2011 23:36:00 GMT"],
        ['Authorization', 'AWS4-HMAC-SHA256 Credential=BAD-CREDENTIAL-SCOPE, SignedHeaders=date;host, Signature=b27ccfbfa7df52a200ff74193ca6e32d4b48b8856fab7ebf1c595d0670a7e470'],
    ]
    expect { call_validate_request(headers) }.to raise_error(EscherError, 'Malformed authorization header')
  end

  it 'should check mandatory signed headers: host' do
    headers = [
        ['Host', 'host.foo.com'],
        ['Date', 'Mon, 09 Sep 2011 23:36:00 GMT'],
        ['Authorization', 'AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20110909/us-east-1/host/aws4_request, SignedHeaders=date, Signature=b27ccfbfa7df52a200ff74193ca6e32d4b48b8856fab7ebf1c595d0670a7e470'],
    ]
    expect { call_validate_request(headers) }.to raise_error(EscherError, 'Host header is not signed')
  end

  it 'should check mandatory signed headers: date' do
    headers = [
        ['Host', 'host.foo.com'],
        ['Date', 'Mon, 09 Sep 2011 23:36:00 GMT'],
        ['Authorization', 'AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20110909/us-east-1/host/aws4_request, SignedHeaders=host, Signature=b27ccfbfa7df52a200ff74193ca6e32d4b48b8856fab7ebf1c595d0670a7e470'],
    ]
    expect { call_validate_request(headers) }.to raise_error(EscherError, 'Date header is not signed')
  end

  it 'should check algorithm' do
    headers = [
        ['Host', 'host.foo.com'],
        ['Date', 'Mon, 09 Sep 2011 23:36:00 GMT'],
        ['Authorization', 'AWS4-HMAC-INVALID Credential=AKIDEXAMPLE/20110909/us-east-1/host/aws4_request, SignedHeaders=date;host, Signature=b27ccfbfa7df52a200ff74193ca6e32d4b48b8856fab7ebf1c595d0670a7e470'],
    ]
    expect { call_validate_request(headers) }.to raise_error(EscherError, 'Unidentified hash algorithm')
  end

  it 'should check credential scope' do
    headers = [
        ['Host', 'host.foo.com'],
        ['Date', 'Mon, 09 Sep 2011 23:36:00 GMT'],
        ['Authorization', 'AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20110909/us-east-1/INVALID/aws4_request, SignedHeaders=date;host, Signature=b27ccfbfa7df52a200ff74193ca6e32d4b48b8856fab7ebf1c595d0670a7e470'],
    ]
    expect { call_validate_request(headers) }.to raise_error(EscherError, 'Invalid credentials')
  end

  def call_validate_request(headers)
    escher = Escher.new(ESCHER_AWS4_OPTIONS.merge(current_time: Time.parse('Mon, 09 Sep 2011 23:40:00 GMT')))
    escher.validate_request('GET', '/', '', headers, key_db)
  end

end

def fixture(test, extension)
  open('spec/aws4_testsuite/'+test+'.'+extension).read
end

def get_host(headers)
  headers.detect {|header| k, v = header; k.downcase == 'host'}[1]
end

def get_date(headers)
  headers.detect {|header| k, v = header; k.downcase == 'date'}[1]
end

def read_request(test, extension = 'req')
  lines = (fixture(test, extension) + "\n").lines.map(&:chomp)
  method, request_uri = lines[0].split ' '
  headers = lines[1..-3].map { |header| k, v = header.split(':', 2); [k, v] }
  request_body = lines[-1]
  [method, request_uri, request_body, headers, get_date(headers), get_host(headers)]
end

def check_canonicalized_request(canonicalized_request, test)
  expect(canonicalized_request).to eq(fixture(test, 'creq'))
end

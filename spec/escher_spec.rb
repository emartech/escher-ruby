require'spec_helper'

test_suites = {
    # 'get-header-key-duplicate',
    # 'get-header-value-order',
    aws4: %w(
      get-header-value-trim
      get-relative
      get-relative-relative
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
    ),
    emarsys: %w(
      get-header-key-duplicate
      post-header-key-order
      post-header-value-spaces
      post-header-value-spaces-within-quotes
    )
}

ESCHER_AWS4_OPTIONS = {
  algo_prefix: 'AWS4', vendor_key: 'Amz', hash_algo: 'SHA256', auth_header_name: 'Authorization', date_header_name: 'Date'
}

ESCHER_EMARSYS_OPTIONS = {
  algo_prefix: 'EMS', vendor_key: 'EMS', hash_algo: 'SHA256', auth_header_name: 'Authorization', date_header_name: 'Date', clock_skew: 10
}

GOOD_AUTH_HEADER = 'AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20110909/us-east-1/host/aws4_request, SignedHeaders=date;host, Signature=b27ccfbfa7df52a200ff74193ca6e32d4b48b8856fab7ebf1c595d0670a7e470'

# noinspection RubyStringKeysInHashInspection
def key_db
  {
      'AKIDEXAMPLE' => 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY',
      'th3K3y'      => 'very_secure',
  }
end

def credential_scope
  %w(us-east-1 host aws4_request)
end

def client
  {:api_key_id => 'AKIDEXAMPLE', :api_secret => 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY'}
end

describe 'Escher' do
  test_suites.each do |suite, tests|
    tests.each do |test|
      it "should calculate canonicalized request for #{test} in #{suite}" do
        escher = Escher.new('us-east-1/host/aws4_request', ESCHER_AWS4_OPTIONS)
        method, request_uri, body, headers = read_request(suite, test)
        headers_to_sign = headers.map {|k| k[0].downcase }
        path, query_parts = escher.parse_uri(request_uri)
        canonicalized_request = escher.canonicalize(method, path, query_parts, body, headers, headers_to_sign)
        check_canonicalized_request(canonicalized_request, suite, test)
      end
    end
  end

  test_suites.each do |suite, tests|
    tests.each do |test|
      it "should calculate string to sign for #{test} in #{suite}" do
        method, request_uri, body, headers, date = read_request(suite, test)
        escher = Escher.new('us-east-1/host/aws4_request', ESCHER_AWS4_OPTIONS.merge(current_time: Time.parse(date)))
        headers_to_sign = headers.map {|k| k[0].downcase }
        path, query_parts = escher.parse_uri(request_uri)
        canonicalized_request = escher.canonicalize(method, path, query_parts, body, headers, headers_to_sign)
        string_to_sign = escher.get_string_to_sign(canonicalized_request)
        expect(string_to_sign).to eq(fixture(suite, test, 'sts'))
      end
    end
  end

  test_suites.each do |suite, tests|
    tests.each do |test|
      it "should calculate auth header for #{test} in #{suite}" do
        method, request_uri, body, headers, date, host = read_request(suite, test)
        escher = Escher.new('us-east-1/host/aws4_request', ESCHER_AWS4_OPTIONS.merge(current_time: Time.parse(date)))
        headers_to_sign = headers.map {|k| k[0].downcase }
        auth_header = escher.generate_auth_header(client, method, host, request_uri, body, headers, headers_to_sign)
        expect(auth_header).to eq(fixture(suite, test, 'authz'))
      end
    end
  end

  it 'should generate presigned url' do
    escher = Escher.new('us-east-1/host/aws4_request', ESCHER_EMARSYS_OPTIONS.merge(current_time: Time.parse('2011/05/11 12:00:00 UTC')))
    expected_url =
        'http://example.com/something?foo=bar&' + 'baz=barbaz&' +
            'X-EMS-Algorithm=EMS-HMAC-SHA256&' +
            'X-EMS-Credentials=th3K3y%2F20110511%2Fus-east-1%2Fhost%2Faws4_request&' +
            'X-EMS-Date=20110511T120000Z&' +
            'X-EMS-Expires=123456&' +
            'X-EMS-SignedHeaders=host&' +
            'X-EMS-Signature=fbc9dbb91670e84d04ad2ae7505f4f52ab3ff9e192b8233feeae57e9022c2b67'

    client = {:api_key_id => 'th3K3y', :api_secret => 'very_secure'}
    expect(escher.generate_signed_url('http://example.com/something?foo=bar&baz=barbaz', client, 123456)).to eq expected_url
  end

  it 'should validate presigned url' do
    escher = Escher.new('us-east-1/host/aws4_request', ESCHER_EMARSYS_OPTIONS.merge(current_time: Time.parse('2011/05/12 21:59:00 UTC')))
    presigned_uri =
        '/something?foo=bar&' + 'baz=barbaz&' +
          'X-EMS-Algorithm=EMS-HMAC-SHA256&' +
          'X-EMS-Credentials=th3K3y%2F20110511%2Fus-east-1%2Fhost%2Faws4_request&' +
          'X-EMS-Date=20110511T120000Z&' +
          'X-EMS-Expires=123456&' +
          'X-EMS-SignedHeaders=host&' +
          'X-EMS-Signature=fbc9dbb91670e84d04ad2ae7505f4f52ab3ff9e192b8233feeae57e9022c2b67'

    client = {:api_key_id => 'th3K3y', :api_secret => 'very_secure'}
    expect { escher.validate_request(key_db, 'GET', presigned_uri, 'IRRELEVANT', [%w(host example.com)]) }.not_to raise_error
  end

  it 'should validate expiration' do
    escher = Escher.new('us-east-1/host/aws4_request', ESCHER_EMARSYS_OPTIONS.merge(current_time: Time.parse('2011/05/12 22:20:00 UTC')))
    presigned_uri =
        '/something?foo=bar&' + 'baz=barbaz&' +
          'X-EMS-Algorithm=EMS-HMAC-SHA256&' +
          'X-EMS-Credentials=th3K3y%2F20110511%2Fus-east-1%2Fhost%2Faws4_request&' +
          'X-EMS-Date=20110511T120000Z&' +
          'X-EMS-Expires=123456&' +
          'X-EMS-SignedHeaders=host&' +
          'X-EMS-Signature=fbc9dbb91670e84d04ad2ae7505f4f52ab3ff9e192b8233feeae57e9022c2b67'

    client = {:api_key_id => 'th3K3y', :api_secret => 'very_secure'}
    expect { escher.validate_request(key_db, 'GET', presigned_uri, 'IRRELEVANT', [%w(host example.com)]) }
      .to raise_error(EscherError, 'The request date is not within the accepted time range')
  end

  it 'should validate request' do
    headers = [
        %w(Host host.foo.com),
        ['Date', 'Mon, 09 Sep 2011 23:36:00 GMT'],
        ['Authorization', GOOD_AUTH_HEADER],
    ]
    expect { call_validate_request(headers) }.not_to raise_error
  end

  it 'should detect if signatures do not match' do
    headers = [
        %w(Host host.foo.com),
        ['Date', 'Mon, 09 Sep 2011 23:36:00 GMT'],
        ['Authorization', 'AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20110909/us-east-1/host/aws4_request, SignedHeaders=date;host, Signature=ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'],
    ]
    expect { call_validate_request(headers) }.to raise_error(EscherError, 'The signatures do not match')
  end

  it 'should detect if dates are not on the same day' do
    yesterday = '08'
    headers = [
        %w(Host host.foo.com),
        ['Date', "Mon, #{yesterday} Sep 2011 23:36:00 GMT"],
        ['Authorization', GOOD_AUTH_HEADER],
    ]
    expect { call_validate_request(headers) }.to raise_error(EscherError, 'Invalid request date')
  end

  it 'should detect if date is not within the 15 minutes range' do
    long_ago = '00'
    headers = [
        %w(Host host.foo.com),
        ['Date', "Mon, 09 Sep 2011 23:#{long_ago}:00 GMT"],
        ['Authorization', GOOD_AUTH_HEADER],
    ]
    expect { call_validate_request(headers) }.to raise_error(EscherError, 'The request date is not within the accepted time range')
  end

  it 'should detect missing host header' do
    headers = [
        ['Date', 'Mon, 09 Sep 2011 23:36:00 GMT'],
        ['Authorization', GOOD_AUTH_HEADER],
    ]
    expect { call_validate_request(headers) }.to raise_error(EscherError, 'Missing header: host')
  end

  it 'should detect missing date header' do
    headers = [
        %w(Host host.foo.com),
        ['Authorization', GOOD_AUTH_HEADER],
    ]
    expect { call_validate_request(headers) }.to raise_error(EscherError, 'Missing header: date')
  end

  it 'should detect missing auth header' do
    headers = [
        %w(Host host.foo.com),
        ['Date', 'Mon, 09 Sep 2011 23:36:00 GMT'],
    ]
    expect { call_validate_request(headers) }.to raise_error(EscherError, 'Missing header: authorization')
  end

  it 'should detect malformed auth header' do
    headers = [
        %w(Host host.foo.com),
        ['Date', 'Mon, 09 Sep 2011 23:36:00 GMT'],
        ['Authorization', 'AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20110909/us-east-1/host/aws4_request, SignedHeaders=date;host, Signature=UNPARSABLE'],
    ]
    expect { call_validate_request(headers) }.to raise_error(EscherError, 'Malformed authorization header')
  end

  it 'should detect malformed credential scope' do
    headers = [
        %w(Host host.foo.com),
        ['Date', 'Mon, 09 Sep 2011 23:36:00 GMT'],
        ['Authorization', 'AWS4-HMAC-SHA256 Credential=BAD-CREDENTIAL-SCOPE, SignedHeaders=date;host, Signature=b27ccfbfa7df52a200ff74193ca6e32d4b48b8856fab7ebf1c595d0670a7e470'],
    ]
    expect { call_validate_request(headers) }.to raise_error(EscherError, 'Malformed authorization header')
  end

  it 'should check mandatory signed headers: host' do
    headers = [
        %w(Host host.foo.com),
        ['Date', 'Mon, 09 Sep 2011 23:36:00 GMT'],
        ['Authorization', 'AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20110909/us-east-1/host/aws4_request, SignedHeaders=date, Signature=b27ccfbfa7df52a200ff74193ca6e32d4b48b8856fab7ebf1c595d0670a7e470'],
    ]
    expect { call_validate_request(headers) }.to raise_error(EscherError, 'Host header is not signed')
  end

  it 'should check mandatory signed headers: date' do
    headers = [
        %w(Host host.foo.com),
        ['Date', 'Mon, 09 Sep 2011 23:36:00 GMT'],
        ['Authorization', 'AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20110909/us-east-1/host/aws4_request, SignedHeaders=host, Signature=b27ccfbfa7df52a200ff74193ca6e32d4b48b8856fab7ebf1c595d0670a7e470'],
    ]
    expect { call_validate_request(headers) }.to raise_error(EscherError, 'Date header is not signed')
  end

  it 'should check algorithm' do
    headers = [
        %w(Host host.foo.com),
        ['Date', 'Mon, 09 Sep 2011 23:36:00 GMT'],
        ['Authorization', 'AWS4-HMAC-INVALID Credential=AKIDEXAMPLE/20110909/us-east-1/host/aws4_request, SignedHeaders=date;host, Signature=b27ccfbfa7df52a200ff74193ca6e32d4b48b8856fab7ebf1c595d0670a7e470'],
    ]
    expect { call_validate_request(headers) }.to raise_error(EscherError, 'Only SHA256 and SHA512 hash algorithms are allowed')
  end

  it 'should check credential scope' do
    headers = [
        %w(Host host.foo.com),
        ['Date', 'Mon, 09 Sep 2011 23:36:00 GMT'],
        ['Authorization', 'AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20110909/us-east-1/INVALID/aws4_request, SignedHeaders=date;host, Signature=b27ccfbfa7df52a200ff74193ca6e32d4b48b8856fab7ebf1c595d0670a7e470'],
    ]
    expect { call_validate_request(headers) }.to raise_error(EscherError, 'Invalid credentials')
  end

  it 'should convert dates' do
    date_str = 'Fri, 09 Sep 2011 23:36:00 GMT'
    expect(Escher.new('irrelevant', date_header_name: 'date', current_time: Time.parse(date_str)).format_date_for_header).to eq date_str
  end

  def call_validate_request(headers)
    escher = Escher.new('us-east-1/host/aws4_request', ESCHER_AWS4_OPTIONS.merge(current_time: Time.parse('Mon, 09 Sep 2011 23:40:00 GMT')))
    escher.validate_request(key_db, 'GET', '/', '', headers)
  end

end

def fixture(suite, test, extension)
  open("spec/#{suite}_testsuite/#{test}.#{extension}").read
end

def get_host(headers)
  headers.detect {|header| header[0].downcase == 'host'}[1]
end

def get_date(headers)
  headers.detect {|header| header[0].downcase == 'date'}[1]
end

def read_request(suite, test, extension = 'req')
  lines = (fixture(suite, test, extension) + "\n").lines.map(&:chomp)
  method, request_uri = lines[0].split ' '
  headers = lines[1..-3].map { |header| k, v = header.split(':', 2); [k, v] }
  request_body = lines[-1]
  [method, request_uri, request_body, headers, get_date(headers), get_host(headers)]
end

def check_canonicalized_request(creq, suite, test)
  expect(creq).to eq(fixture(suite, test, 'creq'))
end

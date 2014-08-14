require 'rspec'
require 'escher'

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
  post-vanilla-query-space
  post-x-www-form-urlencoded
  post-x-www-form-urlencoded-parameters
)
# missing test:   post-vanilla-query-nonunreserved

options = {
    :auth_header_name => 'Authorization',
    :date_header_name => 'Date',
    :vendor_prefix => 'AWS4',
}

describe 'Escher' do
  fixtures.each do |test|
    it "should calculate canonicalized request for #{test}" do
      method, host, request_uri, body, date, headers = read_request(test)
      headers_to_sign = headers.map {|k| k[0].downcase }
      canonicalized_request = Escher.canonicalize method, host, request_uri, body, date, headers, headers_to_sign, 'SHA256', 'Authorization', 'Date'
      check_canonicalized_request(canonicalized_request, test)
    end
  end

  fixtures.each do |test|
    it "should calculate string to sign for #{test}" do
      method, host, request_uri, body, date, headers = read_request(test)
      headers_to_sign = headers.map {|k| k[0].downcase }
      canonicalized_request = Escher.canonicalize method, host, request_uri, body, date, headers, headers_to_sign, 'SHA256', 'Authorization', 'Date'
      string_to_sign = Escher.get_string_to_sign 'us-east-1/host/aws4_request', canonicalized_request, date, 'AWS4', 'SHA256'
                                                     expect(string_to_sign).to eq(fixture(test, 'sts'))
    end
  end

  fixtures.each do |test|
    it "should calculate auth header for #{test}" do
      method, host, request_uri, body, date, headers = read_request(test)
      headers_to_sign = headers.map {|k| k[0].downcase }
      client = {:api_key_id => 'AKIDEXAMPLE', :api_secret => 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY', :credential_scope => 'us-east-1/host/aws4_request'}
      auth_header = Escher.get_auth_header client, method, host, request_uri, body, headers, headers_to_sign, date, 'SHA256', options
      expect(auth_header).to eq(fixture(test, 'authz'))
    end
  end

  it 'should validate request' do
    headers = [
        ['Host', 'host.foo.com'],
        ['Date', 'Mon, 09 Sep 2011 23:36:00 GMT'],
        ['Authorization', 'AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20110909/us-east-1/host/aws4_request, SignedHeaders=date;host, Signature=b27ccfbfa7df52a200ff74193ca6e32d4b48b8856fab7ebf1c595d0670a7e470'],
    ]
    key_db = {'AKIDEXAMPLE' => 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY'}
    expect(Escher.validate_request 'GET', '/', '', headers, key_db, options).to be true
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
  [method, get_host(headers), request_uri, lines[-1], get_date(headers), headers]
end

def check_canonicalized_request(canonicalized_request, test)
  expect(canonicalized_request).to eq(fixture(test, 'creq'))
end

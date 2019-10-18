require 'spec_helper'

module Escher
  describe Auth do

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
      algo_prefix: 'AWS4', vendor_key: 'AWS4', hash_algo: 'SHA256', auth_header_name: 'Authorization', date_header_name: 'Date'
    }

    ESCHER_MIXED_OPTIONS = {
      algo_prefix: 'EMS', vendor_key: 'EMS', hash_algo: 'SHA256', auth_header_name: 'Authorization', date_header_name: 'Date', clock_skew: 10
    }

    ESCHER_EMARSYS_OPTIONS = ESCHER_MIXED_OPTIONS.merge(auth_header_name: 'X-Ems-Auth', date_header_name: 'X-Ems-Date')

    GOOD_AUTH_HEADER = 'AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20110909/us-east-1/host/aws4_request, SignedHeaders=date;host, Signature=b27ccfbfa7df52a200ff74193ca6e32d4b48b8856fab7ebf1c595d0670a7e470'



    def key_db
      {
        'AKIDEXAMPLE' => 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY',
        'th3K3y' => 'very_secure',
      }
    end



    def credential_scope
      %w(us-east-1 host aws4_request)
    end



    def client
      {:api_key_id => 'AKIDEXAMPLE', :api_secret => 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY'}
    end



    test_suites.each do |suite, tests|
      tests.each do |test|
        it "should calculate canonicalized request for #{test} in #{suite}" do
          escher = described_class.new('us-east-1/host/aws4_request', ESCHER_AWS4_OPTIONS)
          method, request_uri, body, headers = read_request(suite, test)
          headers_to_sign = headers.map { |k| k[0].downcase }
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
          escher = described_class.new('us-east-1/host/aws4_request', ESCHER_AWS4_OPTIONS.merge(current_time: Time.parse(date)))
          headers_to_sign = headers.map { |k| k[0].downcase }
          path, query_parts = escher.parse_uri(request_uri)
          canonicalized_request = escher.canonicalize(method, path, query_parts, body, headers, headers_to_sign)
          string_to_sign = escher.get_string_to_sign(canonicalized_request, Time.parse(date))
          expect(string_to_sign).to eq(fixture(suite, test, 'sts'))
        end
      end
    end


    test_suites.each do |suite, tests|
      tests.each do |test|
        it "should calculate auth header for #{test} in #{suite}" do
          method, request_uri, body, headers, date = read_request(suite, test)
          escher = described_class.new('us-east-1/host/aws4_request', ESCHER_AWS4_OPTIONS.merge(current_time: Time.parse(date)))
          headers_to_sign = headers.map { |k| k[0].downcase }
          request = {
            method: method,
            uri: request_uri,
            body: body,
            headers: headers,
          }
          signed_headers = escher.sign!(request, client, headers_to_sign)[:headers].map { |k, v| {k.downcase => v} }.reduce({}, &:merge)
          expect(signed_headers['authorization']).to eq(fixture(suite, test, 'authz'))
        end
      end
    end


    it 'should sign perfect request' do
      escher = described_class.new('us-east-1/iam/aws4_request', ESCHER_EMARSYS_OPTIONS.merge(current_time: Time.parse('20110909T233600Z')))
      client = {:api_key_id => 'AKIDEXAMPLE', :api_secret => 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY'}

      input_headers = [
        ['host', 'iam.amazonaws.com'],
        ['x-ems-date', '20110909T233600Z'],
        ['content-type', 'application/x-www-form-urlencoded; charset=utf-8'],
      ]

      expected_headers = {
        'content-type' => 'application/x-www-form-urlencoded; charset=utf-8',
        'host' => 'iam.amazonaws.com',
        'x-ems-date' => '20110909T233600Z',
        'x-ems-auth' => 'EMS-HMAC-SHA256 Credential=AKIDEXAMPLE/20110909/us-east-1/iam/aws4_request, SignedHeaders=host;x-ems-date, Signature=26855e3e6d3585277965865934f04dcc4c836648873fd2c33f5bbf4f83ebf2a4',
      }

      request = {
        method: 'POST',
        uri: '/',
        body: 'Action=ListUsers&Version=2010-05-08',
        headers: input_headers,
      }

      downcase = escher.sign!(request, client)[:headers].map { |k, v| {k.downcase => v} }.reduce({}, &:merge)
      expect(downcase).to eq expected_headers
    end


    it 'should sign request and add date header' do
      escher = described_class.new('us-east-1/iam/aws4_request', ESCHER_EMARSYS_OPTIONS.merge(current_time: Time.parse('20110909T233600Z')))
      client = {:api_key_id => 'AKIDEXAMPLE', :api_secret => 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY'}

      input_headers = [
          ['host', 'iam.amazonaws.com'],
          ['content-type', 'application/x-www-form-urlencoded; charset=utf-8'],
      ]

      expected_headers = {
          'content-type' => 'application/x-www-form-urlencoded; charset=utf-8',
          'host' => 'iam.amazonaws.com',
          'x-ems-date' => '20110909T233600Z',
          'x-ems-auth' => 'EMS-HMAC-SHA256 Credential=AKIDEXAMPLE/20110909/us-east-1/iam/aws4_request, SignedHeaders=host;x-ems-date, Signature=26855e3e6d3585277965865934f04dcc4c836648873fd2c33f5bbf4f83ebf2a4',
      }

      request = {
          method: 'POST',
          uri: '/',
          body: 'Action=ListUsers&Version=2010-05-08',
          headers: input_headers,
      }

      downcase = escher.sign!(request, client)[:headers].map { |k, v| {k.downcase => v} }.reduce({}, &:merge)
      expect(downcase).to eq expected_headers
    end


    it 'should sign request with headers_to_sign parameter' do
      escher = described_class.new('us-east-1/iam/aws4_request', ESCHER_EMARSYS_OPTIONS.merge(current_time: Time.parse('20110909T233600Z')))
      client = {:api_key_id => 'AKIDEXAMPLE', :api_secret => 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY'}

      input_headers = [
          ['host', 'iam.amazonaws.com'],
          ['x-ems-date', '20110909T233600Z'],
          ['content-type', 'application/x-www-form-urlencoded; charset=utf-8'],
      ]

      expected_headers = {
          'content-type' => 'application/x-www-form-urlencoded; charset=utf-8',
          'host' => 'iam.amazonaws.com',
          'x-ems-date' => '20110909T233600Z',
          'x-ems-auth' => 'EMS-HMAC-SHA256 Credential=AKIDEXAMPLE/20110909/us-east-1/iam/aws4_request, SignedHeaders=content-type;host;x-ems-date, Signature=f36c21c6e16a71a6e8dc56673ad6354aeef49c577a22fd58a190b5fcf8891dbd',
      }

      headers_to_sign = %w(content-type)

      request = {
          method: 'POST',
          uri: '/',
          body: 'Action=ListUsers&Version=2010-05-08',
          headers: input_headers,
      }

      downcase = escher.sign!(request, client, headers_to_sign)[:headers].map { |k, v| {k.downcase => v} }.reduce({}, &:merge)
      expect(downcase).to eq expected_headers
    end


    it 'should generate presigned url' do
      escher = described_class.new('us-east-1/host/aws4_request', ESCHER_MIXED_OPTIONS.merge(current_time: Time.parse('2011/05/11 12:00:00 UTC')))
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


    it 'should generate presigned url with hash parameters' do
      escher = described_class.new('us-east-1/host/aws4_request', ESCHER_MIXED_OPTIONS.merge(current_time: Time.parse('2011/05/11 12:00:00 UTC')))
      expected_url =
        'http://example.com/something?foo=bar&' + 'baz=barbaz&' +
          'X-EMS-Algorithm=EMS-HMAC-SHA256&' +
          'X-EMS-Credentials=th3K3y%2F20110511%2Fus-east-1%2Fhost%2Faws4_request&' +
          'X-EMS-Date=20110511T120000Z&' +
          'X-EMS-Expires=123456&' +
          'X-EMS-SignedHeaders=host&' +
          'X-EMS-Signature=fbc9dbb91670e84d04ad2ae7505f4f52ab3ff9e192b8233feeae57e9022c2b67' +
          '#hash'

      client = {:api_key_id => 'th3K3y', :api_secret => 'very_secure'}
      expect(escher.generate_signed_url('http://example.com/something?foo=bar&baz=barbaz#hash', client, 123456)).to eq expected_url
    end


    it 'should generate presigned url with URL encoded array parameters' do
      escher = described_class.new('us-east-1/host/aws4_request', ESCHER_MIXED_OPTIONS.merge(current_time: Time.parse('2011/05/11 12:00:00 UTC')))
      expected_url =
        'http://example.com/something?arr%5B%5C=apple&' + 'arr%5B%5C=pear&' +
          'X-EMS-Algorithm=EMS-HMAC-SHA256&' +
          'X-EMS-Credentials=th3K3y%2F20110511%2Fus-east-1%2Fhost%2Faws4_request&' +
          'X-EMS-Date=20110511T120000Z&' +
          'X-EMS-Expires=123456&' +
          'X-EMS-SignedHeaders=host&' +
          'X-EMS-Signature=4d874d872a1df27f05d810592f98a3020ddfb92627043ebf255c86058fa1b93a'

      client = {:api_key_id => 'th3K3y', :api_secret => 'very_secure'}
      expect(escher.generate_signed_url('http://example.com/something?arr%5B%5C=apple&arr%5B%5C=pear', client, 123456)).to eq expected_url
    end

    it 'should generate presigned url with URL encoded' do
              escher = described_class.new('us-east-1/host/aws4_request', ESCHER_MIXED_OPTIONS.merge(current_time: Time.parse('2011/05/11 12:00:00 UTC')))
              expected_url =
                'http://example.com/something?tz=Europe%2FVienna&' +
                  'X-EMS-Algorithm=EMS-HMAC-SHA256&' +
                  'X-EMS-Credentials=th3K3y%2F20110511%2Fus-east-1%2Fhost%2Faws4_request&' +
                  'X-EMS-Date=20110511T120000Z&' +
                  'X-EMS-Expires=123456&' +
                  'X-EMS-SignedHeaders=host&' +
                  'X-EMS-Signature=b73d097c8c8ea1a954ffebafec84884ce2a487b001d62ccd71787964d01df39b'

              client = {:api_key_id => 'th3K3y', :api_secret => 'very_secure'}
              expect(escher.generate_signed_url('http://example.com/something?tz=Europe%2FVienna', client, 123456)).to eq expected_url
            end

    it 'should validate double encoded presigned url' do
          escher = described_class.new('us-east-1/host/aws4_request', ESCHER_MIXED_OPTIONS.merge(current_time: Time.parse('2011/05/12 21:59:00 UTC')))
          presigned_uri =
            '/something?tz=Europe%2FVienna&' +
            'X-EMS-Algorithm=EMS-HMAC-SHA256&' +
            'X-EMS-Credentials=th3K3y%2F20110511%2Fus-east-1%2Fhost%2Faws4_request&' +
            'X-EMS-Date=20110511T120000Z&' +
            'X-EMS-Expires=123456&' +
            'X-EMS-SignedHeaders=host&' +
            'X-EMS-Signature=b73d097c8c8ea1a954ffebafec84884ce2a487b001d62ccd71787964d01df39b'

          client = {:api_key_id => 'th3K3y', :api_secret => 'very_secure'}
          expect { escher.authenticate({
                                         :method => 'GET',
                                         :headers => [%w(host example.com)],
                                         :uri => presigned_uri,
                                         :body => 'IRRELEVANT'
                                       }, key_db) }.not_to raise_error
        end

    it 'should generate presigned url with double URL encoded' do
          escher = described_class.new('us-east-1/host/aws4_request', ESCHER_MIXED_OPTIONS.merge(current_time: Time.parse('2011/05/11 12:00:00 UTC')))
          expected_url =
            'http://example.com/something?tz=Europe%252FVienna&' +
              'X-EMS-Algorithm=EMS-HMAC-SHA256&' +
              'X-EMS-Credentials=th3K3y%2F20110511%2Fus-east-1%2Fhost%2Faws4_request&' +
              'X-EMS-Date=20110511T120000Z&' +
              'X-EMS-Expires=123456&' +
              'X-EMS-SignedHeaders=host&' +
              'X-EMS-Signature=8eeb0171cf2acc4efcb6b3ff13a53d49ab3ee98d631898608d0ebf9de7281066'

          client = {:api_key_id => 'th3K3y', :api_secret => 'very_secure'}
          expect(escher.generate_signed_url('http://example.com/something?tz=Europe%252FVienna', client, 123456)).to eq expected_url
        end

    it 'should validate double encoded presigned url' do
          escher = described_class.new('us-east-1/host/aws4_request', ESCHER_MIXED_OPTIONS.merge(current_time: Time.parse('2011/05/12 21:59:00 UTC')))
          presigned_uri =
            '/something?tz=Europe%252FVienna&' +
              'X-EMS-Algorithm=EMS-HMAC-SHA256&' +
              'X-EMS-Credentials=th3K3y%2F20110511%2Fus-east-1%2Fhost%2Faws4_request&' +
              'X-EMS-Date=20110511T120000Z&' +
              'X-EMS-Expires=123456&' +
              'X-EMS-SignedHeaders=host&' +
              'X-EMS-Signature=8eeb0171cf2acc4efcb6b3ff13a53d49ab3ee98d631898608d0ebf9de7281066'

          client = {:api_key_id => 'th3K3y', :api_secret => 'very_secure'}
          expect { escher.authenticate({
                                         :method => 'GET',
                                         :headers => [%w(host example.com)],
                                         :uri => presigned_uri,
                                         :body => 'IRRELEVANT'
                                       }, key_db) }.not_to raise_error
        end

    [
        ['http://iam.amazonaws.com:5000/', 'iam.amazonaws.com:5000'],
        ['https://iam.amazonaws.com:5000/', 'iam.amazonaws.com:5000'],
        ['http://iam.amazonaws.com:80/', 'iam.amazonaws.com'],
        ['https://iam.amazonaws.com:443/', 'iam.amazonaws.com'],
        ['http://iam.amazonaws.com:443/', 'iam.amazonaws.com:443'],
        ['https://iam.amazonaws.com:80/', 'iam.amazonaws.com:80']
    ].each do |input, expected_output|
      it 'should automagically handle ports' do
        escher = described_class.new('us-east-1/host/aws4_request', ESCHER_MIXED_OPTIONS.merge(current_time: Time.parse('2011/05/11 12:00:00 UTC')))
        client = {:api_key_id => 'th3K3y', :api_secret => 'very_secure'}
        expect(escher.generate_signed_url("#{input}something?foo=bar&baz=barbaz#hash", client, 123456)).to include expected_output
      end
    end


    it 'should validate presigned url' do
      escher = described_class.new('us-east-1/host/aws4_request', ESCHER_MIXED_OPTIONS.merge(current_time: Time.parse('2011/05/12 21:59:00 UTC')))
      presigned_uri =
        '/something?foo=bar&' + 'baz=barbaz&' +
          'X-EMS-Algorithm=EMS-HMAC-SHA256&' +
          'X-EMS-Credentials=th3K3y%2F20110511%2Fus-east-1%2Fhost%2Faws4_request&' +
          'X-EMS-Date=20110511T120000Z&' +
          'X-EMS-Expires=123456&' +
          'X-EMS-SignedHeaders=host&' +
          'X-EMS-Signature=fbc9dbb91670e84d04ad2ae7505f4f52ab3ff9e192b8233feeae57e9022c2b67'

      client = {:api_key_id => 'th3K3y', :api_secret => 'very_secure'}
      expect { escher.authenticate({
                                     :method => 'GET',
                                     :headers => [%w(host example.com)],
                                     :uri => presigned_uri,
                                     :body => 'IRRELEVANT'
                                   }, key_db) }.not_to raise_error
    end


    it 'should validate expiration' do
      escher = described_class.new('us-east-1/host/aws4_request', ESCHER_MIXED_OPTIONS.merge(current_time: Time.parse('2011/05/12 22:20:00 UTC')))
      presigned_uri =
        '/something?foo=bar&' + 'baz=barbaz&' +
          'X-EMS-Algorithm=EMS-HMAC-SHA256&' +
          'X-EMS-Credentials=th3K3y%2F20110511%2Fus-east-1%2Fhost%2Faws4_request&' +
          'X-EMS-Date=20110511T120000Z&' +
          'X-EMS-Expires=123456&' +
          'X-EMS-SignedHeaders=host&' +
          'X-EMS-Signature=fbc9dbb91670e84d04ad2ae7505f4f52ab3ff9e192b8233feeae57e9022c2b67'

      client = {:api_key_id => 'th3K3y', :api_secret => 'very_secure'}
      expect { escher.authenticate({
                                     :method => 'GET',
                                     :headers => [%w(host example.com)],
                                     :uri => presigned_uri,
                                     :body => 'IRRELEVANT'
                                   }, key_db) }.to raise_error(EscherError, 'The request date is not within the accepted time range')
    end


    it 'should validate request' do
      headers = [
        %w(Host host.foo.com),
        ['Date', 'Mon, 09 Sep 2011 23:36:00 GMT'],
        ['Authorization', GOOD_AUTH_HEADER],
      ]
      expect { call_validate(headers) }.not_to raise_error
    end


    it 'should authenticate' do
      headers = [
        %w(Host host.foo.com),
        ['Date', 'Mon, 09 Sep 2011 23:36:00 GMT'],
        ['Authorization', GOOD_AUTH_HEADER],
      ]
      expect(call_validate(headers)).to eq 'AKIDEXAMPLE'
    end


    it 'should not throw parse error if credential scope contains whitespaces' do
      headers = [
          %w(Host host.foo.com),
          ['Date', 'Mon, 09 Sep 2011 23:36:00 GMT'],
          ['Authorization', 'AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20110909/us-ea st-1/host/aws4_request, SignedHeaders=date;host, Signature=b27ccfbfa7df52a200ff74193ca6e32d4b48b8856fab7ebf1c595d0670a7e470'],
      ]
      expect { call_validate(headers) }.to raise_error(EscherError, 'Invalid Credential Scope')
    end


    it 'should detect if signatures do not match' do
      headers = [
        %w(Host host.foo.com),
        ['Date', 'Mon, 09 Sep 2011 23:36:00 GMT'],
        ['Authorization', 'AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20110909/us-east-1/host/aws4_request, SignedHeaders=date;host, Signature=ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'],
      ]
      expect { call_validate(headers) }.to raise_error(EscherError, 'The signatures do not match')
    end


    it 'should detect if date is not within the 15 minutes range' do
      long_ago = '00'
      headers = [
        %w(Host host.foo.com),
        ['Date', "Mon, 09 Sep 2011 23:#{long_ago}:00 GMT"],
        ['Authorization', GOOD_AUTH_HEADER],
      ]
      expect { call_validate(headers) }.to raise_error(EscherError, 'The request date is not within the accepted time range')
    end


    it 'should detect malformed auth header' do
      headers = [
        %w(Host host.foo.com),
        ['Date', 'Mon, 09 Sep 2011 23:36:00 GMT'],
        ['Authorization', 'AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20110909/us-east-1/host/aws4_request, SignedHeaders=date;host, Signature=UNPARSABLE'],
      ]
      expect { call_validate(headers) }.to raise_error(EscherError, 'Invalid auth header format')
    end


    it 'should detect malformed credential scope' do
      headers = [
        %w(Host host.foo.com),
        ['Date', 'Mon, 09 Sep 2011 23:36:00 GMT'],
        ['Authorization', 'AWS4-HMAC-SHA256 Credential=BAD-CREDENTIAL-SCOPE, SignedHeaders=date;host, Signature=b27ccfbfa7df52a200ff74193ca6e32d4b48b8856fab7ebf1c595d0670a7e470'],
      ]
      expect { call_validate(headers) }.to raise_error(EscherError, 'Invalid auth header format')
    end


    it 'should check mandatory signed headers: host' do
      headers = [
        %w(Host host.foo.com),
        ['Date', 'Mon, 09 Sep 2011 23:36:00 GMT'],
        ['Authorization', 'AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20110909/us-east-1/host/aws4_request, SignedHeaders=date, Signature=b27ccfbfa7df52a200ff74193ca6e32d4b48b8856fab7ebf1c595d0670a7e470'],
      ]
      expect { call_validate(headers) }.to raise_error(EscherError, 'The host header is not signed')
    end


    it 'should check mandatory signed headers: date' do
      headers = [
        %w(Host host.foo.com),
        ['Date', 'Mon, 09 Sep 2011 23:36:00 GMT'],
        ['Authorization', 'AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20110909/us-east-1/host/aws4_request, SignedHeaders=host, Signature=b27ccfbfa7df52a200ff74193ca6e32d4b48b8856fab7ebf1c595d0670a7e470'],
      ]
      expect { call_validate(headers) }.to raise_error(EscherError, 'The date header is not signed')
    end


    it 'should convert dates' do
      date_str = 'Fri, 09 Sep 2011 23:36:00 GMT'
      expect(described_class.new('irrelevant', date_header_name: 'date', current_time: Time.parse(date_str)).format_date_for_header(Time.parse(date_str))).to eq date_str
    end



    def call_validate(headers)
      escher = described_class.new('us-east-1/host/aws4_request', ESCHER_AWS4_OPTIONS.merge(current_time: Time.parse('Mon, 09 Sep 2011 23:40:00 GMT')))
      escher.authenticate({
                            :method => 'GET',
                            :headers => headers,
                            :uri => '/',
                            :body => '',
                          }, key_db)
    end



    def fixture(suite, test, extension)
      open("spec/#{suite}_testsuite/#{test}.#{extension}").read
    end



    def get_host(headers)
      headers.detect { |header| header[0].downcase == 'host' }[1]
    end



    def get_date(headers)
      headers.detect { |header| header[0].downcase == 'date' }[1]
    end



    def read_request(suite, test, extension = 'req')
      lines = (fixture(suite, test, extension) + "\n").lines.map(&:chomp)
      method, uri = lines[0].split ' '
      headers = lines[1..-3].map { |header| k, v = header.split(':', 2); [k, v] }
      body = lines[-1]
      [method, uri, body, headers, get_date(headers), get_host(headers)]
    end



    def check_canonicalized_request(creq, suite, test)
      expect(creq).to eq(fixture(suite, test, 'creq'))
    end

  end
end

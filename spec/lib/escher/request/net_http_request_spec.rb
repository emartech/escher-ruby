require 'spec_helper'
require 'net/http'

describe Escher::Request::NetHttpRequest do
  let(:default_headers) do
    [
      ["accept-encoding", "gzip;q=1.0,deflate;q=0.6,identity;q=0.3"],
      ["accept", "*/*"],
      ["user-agent", "Ruby"]
    ]
  end
  let(:default_header_key) { 'accept' }
  let(:default_header_value) { '*/*' }
  let(:path) { '/path?a=10&b=20' }
  let(:request) { Net::HTTP::Post.new(path) }
  let(:inexisting_header_key) { 'Inexisting-Header' }
  subject(:net_http_request) { described_class.new(request) }

  describe "#request" do
    it 'returns the underlying request object' do
      expect(net_http_request.request).to eq(request)
    end
  end

  describe "#headers" do
    it 'returns request headers' do
      expect(net_http_request.headers).to eq(default_headers)
    end
  end

  describe "#has_header?" do
    it 'returns true if request has specified header' do
      expect(net_http_request.has_header?(default_header_key)).to be true
    end

    it "returns false if request doesn't have specified header" do
      expect(net_http_request.has_header?(inexisting_header_key)).to be false
    end
  end

  describe "#header" do
    it 'returns the value for the requested header' do
      expect(net_http_request.header(default_header_key)).to eq(default_header_value)
    end

    it 'returns nil if header is not present' do
      expect(net_http_request.header(inexisting_header_key)).to eq nil
    end
  end

  describe "#method" do
    it 'returns request method' do
      expect(net_http_request.method).to eq('POST')
    end
  end

  describe "#body" do
    it 'returns request body' do
      request.body = 'body'

      expect(net_http_request.body).to eq('body')
    end

    it 'returns empty string if no body' do
      expect(net_http_request.body).to eq('')
    end
  end

  describe "#path" do
    it 'returns request path' do
      expect(net_http_request.path).to eq(URI(request.path).path)
    end
  end

  describe "#query_values" do
    it 'returns query values' do
      expect(net_http_request.query_values).to eq([["a", "10"], ["b", "20"]])
    end
  end

  describe "#set_header" do
    it 'sets the header' do
      net_http_request.set_header('test-header', 'test value')

      expect(net_http_request.header('test-header')).to eq('test value')
    end
  end
end

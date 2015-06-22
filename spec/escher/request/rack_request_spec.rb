require 'spec_helper'

require 'rack'
require 'rack/request'

describe Escher::Request::RackRequest do

  let(:request_params) { {"PATH_INFO" => "/", } }
  let(:request) { Rack::Request.new request_params }

  subject { described_class.new request }


  describe "#request" do
    it "should return the underlying request object" do
      expect(subject.request).to eq request
    end
  end


  describe "#headers" do
    it "should return only the HTTP request headers" do
      request_params.merge! 'HTTP_HOST' => 'some host',
                            'SOME_HEADER' => 'some header'

      expect(subject.headers).to eq [['HOST', 'some host']]
    end

    it "should replace underscores with dashes in the header name" do
      request_params.merge! 'HTTP_HOST_NAME' => 'some host'

      expect(subject.headers).to eq [['HOST-NAME', 'some host']]
    end


    it 'should add the content-type and content-length to the headers' do
      request_params.merge!( 'CONTENT_LENGTH' => '123', 'CONTENT_TYPE' => 'text/plain' )

      expect(subject.headers).to eq [%w(CONTENT_LENGTH 123), %w(CONTENT_TYPE text/plain)]
    end
  end


  describe "#has_header?" do
    it "should return true if request has specified header, false otherwise" do
      request_params.merge! 'HTTP_HOST_NAME' => 'some host'

      expect(subject.has_header? 'host-name').to be_truthy
      expect(subject.has_header? 'no-such-header').to be_falsey
    end
  end


  describe "#header" do
    it "should return the value for the requested header" do
      request_params.merge! 'HTTP_HOST' => 'some host'

      expect(subject.header 'host').to eq 'some host'
    end

    it "should return nil if no such header exists" do
      expect(subject.header 'host').to be_nil
    end
  end


  describe "#method" do
    it "should return the request method" do
      request_params.merge! 'REQUEST_METHOD' => 'GET'

      expect(subject.method).to eq 'GET'
    end
  end


  describe "#body" do
    it "should return the request body" do
      request_params.merge! 'rack.input' => 'request body'

      expect(subject.body).to eq 'request body'
    end

    it "should return empty string for no body" do
      expect(subject.body).to eq ''
    end
  end


  describe "#path" do
    it "should return the request path" do
      request_params.merge! 'REQUEST_PATH' => '/resources/id///'

      expect(subject.path).to eq '/resources/id///'
    end
  end


  describe "#query_values" do
    it "should return the request query parameters as an array of key-value pairs" do
      request_params.merge! 'QUERY_STRING' => 'search=query&param=value'

      expect(subject.query_values).to eq [['search', 'query'], ['param', 'value']]
    end

    it "should return the query parameters regardless of fragments" do
      request_params.merge! 'QUERY_STRING' => "@\#$%^&+=/,?><`\";:\\|][{}"

      expect(subject.query_values).to eq [["@\#$%^"], ["+", "/,?><`\";:\\|][{}"]]
    end

    it "should return an empty array if the request has no query parameters" do
      expect(subject.query_values).to eq []
    end
  end


  describe "#set_header" do
    it "should ignore calls" do
      expect { subject.set_header 'test-header', 'test value' }.not_to raise_error
    end
  end

end

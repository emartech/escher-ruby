require 'spec_helper'

describe Escher::Request::HashRequest do

  let(:request) { {headers: [], uri: '/'} }
  subject { described_class.new request }


  describe "#request" do
    it "should return the underlying request object" do
      expect(subject.request).to eq request
    end
  end


  describe "#headers" do
    it "should return the request headers" do
      request[:headers] = [['HOST', 'some host'],
                           ['SOME_HEADER', 'some header']]

      expect(subject.headers).to eq [['HOST', 'some host'],
                                     ['SOME-HEADER', 'some header']]
    end
  end


  describe "#has_header?" do
    it "should return true if request has specified header, false otherwise" do
      request[:headers] = [['HOST', 'some host']]

      expect(subject.has_header? 'host').to be_truthy
      expect(subject.has_header? 'no-such-header').to be_falsey
    end
  end


  describe "#header" do
    it "should return the value for the requested header" do
      request[:headers] = [['HOST', 'some host']]

      expect(subject.header 'host').to eq 'some host'
    end

    it "should return nil if no such header exists" do
      expect(subject.header 'host').to be_nil
    end
  end


  describe "#set_header" do
    it "should add the specified header to the request" do
      subject.set_header 'TEST_HEADER', 'test value'

      expect(subject.has_header? 'test-header').to be_truthy
      expect(subject.header 'test-header').to eq 'test value'
    end

    it "should return nil if no such header exists" do
      expect(subject.header 'no-such-header').to be_nil
    end
  end


  describe "#method" do
    it "should return the request method" do
      request[:method] = 'GET'

      expect(subject.method).to eq 'GET'
    end
  end


  describe "#body" do
    it "should return the request body" do
      request[:body] = 'request body'

      expect(subject.body).to eq 'request body'
    end

    it "should return empty string for no body" do
      expect(subject.body).to eq ''
    end
  end


  describe "#path" do
    it "should return the request path" do
      request[:uri] = '/resources/id?search=query'

      expect(subject.path).to eq '/resources/id'
    end

    it "should return the original path unnormalized" do
      request[:uri] = '//'

      expect(subject.path).to eq '//'
    end
  end


  describe "#query_values" do
    it "should return the request query parameters as an array of key-value pairs" do
      request[:uri] = '/resources/id?search=query&param=value'

      expect(subject.query_values).to eq [['search', 'query'], ['param', 'value']]
    end

    it "should return the query parameters regardless of fragments" do
      request[:uri] = "/?@\#$%^&+=/,?><`\";:\\|][{}"

      expect(subject.query_values).to eq [["@\#$%^"], ["+", "/,?><`\";:\\|][{}"]]
    end

    it "should return an empty array if the request has no query parameters" do
      request[:uri] = '/resources/id'

      expect(subject.query_values).to eq []
    end
  end

end

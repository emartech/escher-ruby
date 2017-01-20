require 'spec_helper'

require 'rack'
require 'rack/request'
require 'action_dispatch'

describe Escher::Request::Factory do

  describe ".from_request" do
    request_env = {Rack::PATH_INFO.to_s => "request-path"}

    {

      {uri: "request-path"} => Escher::Request::HashRequest,
      Struct.new("Request", :uri).new("request-path") => Escher::Request::LegacyRequest,
      Rack::Request.new(request_env) => Escher::Request::RackRequest,
      ActionDispatch::Request.new(request_env) => Escher::Request::RackRequest

    }.each do |request, expected_class|

      context "the request to be wrapped is a #{request.class.name}" do

        it "returns a #{expected_class.name}" do
          wrapped_request = described_class.from_request request

          expect(wrapped_request).to be_an_instance_of expected_class
        end

        it "wraps the path from the original request" do
          wrapped_request = described_class.from_request request

          expect(wrapped_request.path).to eq "request-path"
        end

      end

    end

  end
end

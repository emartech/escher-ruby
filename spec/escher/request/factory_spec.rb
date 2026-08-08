require 'spec_helper'

require 'rack'
require 'rack/request'
require 'action_dispatch'
require 'net/http'

describe Escher::Request::Factory do

  describe ".from_request" do
    request_env = {Rack::PATH_INFO.to_s => "request-path"}
    ruby_request_classes = [
      Net::HTTP::Get, Net::HTTP::Head, Net::HTTP::Post, Net::HTTP::Put, Net::HTTP::Delete,
      Net::HTTP::Options, Net::HTTP::Trace, Net::HTTP::Patch, Net::HTTP::Propfind, Net::HTTP::Proppatch,
      Net::HTTP::Mkcol, Net::HTTP::Copy, Net::HTTP::Move, Net::HTTP::Lock, Net::HTTP::Unlock
    ]

    request_types = {

      {uri: "request-path"} => Escher::Request::HashRequest,
      Struct.new("Request", :uri).new("request-path") => Escher::Request::LegacyRequest,
      Rack::Request.new(request_env) => Escher::Request::RackRequest,
      ActionDispatch::Request.new(request_env) => Escher::Request::RackRequest

    }

    ruby_request_classes.each do |net_http_request_type|
      request_types[net_http_request_type.new("request-path")] = Escher::Request::NetHttpRequest
    end

    request_types.each do |request, expected_class|

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

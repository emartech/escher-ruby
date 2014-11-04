require 'spec_helper'
require 'rack/request'

describe Escher::Request::Factory do

  describe ".from_request" do
    {{uri: "request uri"} => Escher::Request::HashRequest,
     Struct.new(:uri) => Escher::Request::LegacyRequest,
     Rack::Request.new({}) => Escher::Request::RackRequest}.each do |request, expected_class|

      it "should return a #{expected_class.name} when the request to be wrapped is a #{request.class.name}" do
        expect(expected_class).to receive(:new).with(request).and_return "#{expected_class.name} wrapping request"

        expect(described_class.from_request request).to eq "#{expected_class.name} wrapping request"
      end

    end

  end
end

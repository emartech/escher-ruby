require 'spec_helper'
require 'json'
require 'plissken'
require 'date'


module Escher
  describe Auth do

    def self.sign_request_valid
      Dir.glob('./spec/emarsys_test_suite/signrequest-*').reject { |c| c.include? 'error'}
    end


    Dir.glob('./spec/emarsys_test_suite/authenticate-error-*').each do |c|
      test_case = ::JSON.parse(File.read(c), symbolize_names: true).to_snake_keys
      test_case[:request][:uri] = test_case[:request].delete :url
      test_case[:config][:current_time] = Time.parse(test_case[:config].delete :date)
      escher = Auth.new(test_case[:config][:credential_scope], test_case[:config])
      key = {test_case[:key_db].first[0] => test_case[:key_db].first[1]}

      it "#{test_case[:title]}" do
        expect { escher.authenticate(test_case[:request], key, test_case[:mandatory_signed_headers]) }
          .to raise_error(EscherError, test_case[:expected][:error])
      end
    end


    Dir.glob('./spec/emarsys_test_suite/authenticate-valid-*').each do |c|
      test_case = ::JSON.parse(File.read(c), symbolize_names: true).to_snake_keys
      test_case[:request][:uri] = test_case[:request].delete :url
      test_case[:config][:current_time] = Time.parse(test_case[:config].delete :date)
      escher = Auth.new(test_case[:config][:credential_scope], test_case[:config])
      key = {test_case[:key_db].first[0] => test_case[:key_db].first[1]}

      it "#{test_case[:title]}" do
        expect { escher.authenticate(test_case[:request], key) }.not_to raise_error
      end
    end


    Dir.glob('./spec/emarsys_test_suite/presignurl-*').each do |c|
      test_case = ::JSON.parse(File.read(c), symbolize_names: true).to_snake_keys
      test_case[:config][:api_key_id] = test_case[:config].delete :access_key_id
      test_case[:config][:current_time] = Time.parse(test_case[:config].delete :date)
      escher = Auth.new(test_case[:config][:credential_scope], test_case[:config])

      it "#{test_case[:title]}" do
        expect(escher.generate_signed_url(test_case[:request][:url], test_case[:config], test_case[:request][:expires]))
          .to eq(test_case[:expected][:url])
      end
    end


    sign_request_valid.each do |c|
      test_case = ::JSON.parse(File.read(c), symbolize_names: true).to_snake_keys
      test_case[:config][:api_key_id] = test_case[:config].delete :access_key_id
      test_case[:config][:current_time] = Time.parse(test_case[:config].delete :date)
      test_case[:request][:uri] = test_case[:request].delete :url
      escher = Auth.new(test_case[:config][:credential_scope], test_case[:config])

      it "#{test_case[:title]}" do
        request = escher.sign! test_case[:request], test_case[:config], test_case[:headers_to_sign]
        request[:url] = request.delete :uri
        request.each { |_, v| v.sort! if v.class.method_defined? :sort! }

        expected_request = test_case[:expected][:request]
        expected_request.each { |_, v| v.sort! if v.class.method_defined? :sort! }

        expect(request).to eq(expected_request)
      end
    end

  end

end

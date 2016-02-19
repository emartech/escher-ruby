require 'spec_helper'

module Escher

  describe Auth, :emarsys_test_suite do

    authentication_error_test_files.each do |test_file|
      test_case = EmarsysTestSuiteHelpers::TestCase.new test_file
      test_case[:request][:uri] = test_case[:request].delete :url

      escher = create_escher_for test_case
      key = extract_key(test_case)

      it "#{test_case[:title]}" do
        expect { escher.authenticate(test_case[:request], key, test_case[:mandatory_signed_headers]) }
          .to raise_error(EscherError, test_case[:expected][:error])
      end
    end


    authentication_valid_test_files.each do |test_file|
      test_case = EmarsysTestSuiteHelpers::TestCase.new test_file
      test_case[:request][:uri] = test_case[:request].delete :url

      escher = create_escher_for test_case
      key = extract_key(test_case)

      it "#{test_case[:title]}" do
        expect { escher.authenticate(test_case[:request], key) }.not_to raise_error
      end
    end


    presign_url_test_files.each do |test_file|
      test_case = EmarsysTestSuiteHelpers::TestCase.new test_file
      test_case[:config][:api_key_id] = test_case[:config].delete :access_key_id

      escher = create_escher_for test_case

      it "#{test_case[:title]}" do
        expect(escher.generate_signed_url(test_case[:request][:url], test_case[:config], test_case[:request][:expires]))
          .to eq(test_case[:expected][:url])
      end
    end


    sign_request_valid_test_files.each do |test_file|
      test_case = EmarsysTestSuiteHelpers::TestCase.new test_file
      test_case[:request][:uri] = test_case[:request].delete :url
      test_case[:config][:api_key_id] = test_case[:config].delete :access_key_id

      escher = create_escher_for test_case

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

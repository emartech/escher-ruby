require 'json'
require 'plissken'
require 'escher'

module EmarsysTestSuiteHelpers

  def authentication_error_test_files
    Dir.glob('./spec/emarsys_test_suite/authenticate-error-*')
  end



  def authentication_valid_test_files
    Dir.glob('./spec/emarsys_test_suite/authenticate-valid-*')
  end



  def presign_url_test_files
    Dir.glob('./spec/emarsys_test_suite/presignurl-*')
  end



  def sign_request_valid_test_files
    Dir.glob('./spec/emarsys_test_suite/signrequest-*').reject { |c| c.include? 'error' }
  end



  class TestCase

    def initialize(test_file)
      @test_data = ::JSON.parse(File.read(test_file), symbolize_names: true).to_snake_keys
    end



    def [](arg)
      @test_data[arg]
    end



    def key
      {@test_data[:key_db].first[0] => @test_data[:key_db].first[1]}
    end



    def escher
      @test_data[:config][:current_time] = Time.parse(@test_data[:config].delete :date)
      @escher ||= ::Escher::Auth.new(@test_data[:config][:credential_scope], @test_data[:config])
    end

  end

end

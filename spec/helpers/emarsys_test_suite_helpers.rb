require 'json'
require 'plissken'
require 'escher'

module EmarsysTestSuiteHelpers
  def create_test_case
    ->(t) { EmarsysTestSuiteHelpers::TestCase.new t }
  end



  def authentication_error_test_files
    Dir.glob('./spec/emarsys_test_suite/authenticate-error-*').map &create_test_case
  end



  def authentication_valid_test_files
    Dir.glob('./spec/emarsys_test_suite/authenticate-valid-*').map &create_test_case
  end



  def presign_url_test_files
    Dir.glob('./spec/emarsys_test_suite/presignurl-*').map &create_test_case
  end



  def sign_request_valid_test_files
    files = Dir.glob('./spec/emarsys_test_suite/signrequest-*').reject { |c| c.include? 'error' }
    files.map &create_test_case
  end



  class TestCase

    def initialize(test_file)
      @test_data = ::JSON.parse(File.read(test_file), symbolize_names: true).to_snake_keys
      convert_naming
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



    def expected_request
      @test_data[:expected][:request].each { |_, v| v.sort! if v.class.method_defined? :sort! }
    end



    private
    def convert_naming
      @test_data[:request][:uri] = @test_data[:request].delete :url
      @test_data[:config][:api_key_id] = @test_data[:config].delete :access_key_id
    end

  end

end

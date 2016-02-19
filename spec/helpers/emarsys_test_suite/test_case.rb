module EmarsysTestSuiteHelpers
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
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



  def parse_test_from(test_file)
    ::JSON.parse(File.read(test_file), symbolize_names: true).to_snake_keys
  end



  def create_escher_for(test_case)
    test_case[:config][:current_time] = Time.parse(test_case[:config].delete :date)
    ::Escher::Auth.new(test_case[:config][:credential_scope], test_case[:config])
  end



  def extract_key(test_case)
    {test_case[:key_db].first[0] => test_case[:key_db].first[1]}
  end

end

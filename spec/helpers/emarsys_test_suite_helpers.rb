require 'json'
require 'plissken'
require 'escher'

module EmarsysTestSuiteHelpers

  autoload :TestCase, 'helpers/emarsys_test_suite/test_case'
  autoload :TestSuite, 'helpers/emarsys_test_suite/test_suite'



  def create_test_case
    ->(t) { TestCase.new t }
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

end

lib = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'escher'


autoload :EmarsysTestSuiteHelpers, 'helpers/emarsys_test_suite_helpers'
RSpec.configure do |c|
  c.extend EmarsysTestSuiteHelpers, :emarsys_test_suite
end

module EmarsysTestSuiteHelpers
  class TestSuite

    def self.size
      Dir.glob('./spec/emarsys_test_suite/*').size
    end



    def self.in_use_size
      size = Dir.glob('./spec/emarsys_test_suite/authenticate-error-*').size
      size += Dir.glob('./spec/emarsys_test_suite/authenticate-valid-*').size
      size += Dir.glob('./spec/emarsys_test_suite/presignurl-*').size
      size + Dir.glob('./spec/emarsys_test_suite/signrequest-*').reject { |c| c.include? 'error' }.size
    end

  end
end

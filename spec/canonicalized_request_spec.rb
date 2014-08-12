require 'rspec'
require 'escher'

fixtures = %w(get-vanilla-query post-x-www-form-urlencoded)

describe 'Escher' do
  fixtures.each do |test|
    it "should calculate canonicalized request for #{test}" do
        method, url, body, date, headers = read_request(test)
        headers_to_sign = headers.keys.map(&:downcase)
        canonicalized_request = Escher.new.canonicalize method, url, body, date, headers, headers_to_sign
        expect(canonicalized_request).to eq(fixture(test, 'creq'))
    end
  end
end

def fixture(test, extension)
  open('spec/aws4_testsuite/'+test+'.'+extension).read
end

def read_request(test)
  lines = (fixture(test, 'req') + "\n").lines.map(&:chomp)
  method, uri = lines[0].split ' '
  headers = lines[1..-3].map { |header| k, v = header.split(':', 2); {k => v} }.reduce(&:merge)
  url = 'http://'+ headers['Host'] + uri

  body = lines[-1]
  date = headers['Date']
  return method, url, body, date, headers
end

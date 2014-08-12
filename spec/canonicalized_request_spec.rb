require 'rspec'
require 'escher'

describe 'Canonicalized request' do

  it 'should calculate canonicalized form of simple get request' do

    canonicalized_request = Escher.new.canonicalize 'GET', 'http://host.foo.com/', '', 'Mon, 09 Sep 2011 23:36:00 GMT', {}
    expect(canonicalized_request).to eq(
                                         'GET
/

date:Mon, 09 Sep 2011 23:36:00 GMT
host:host.foo.com

date;host
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855')

  end

  it 'should calculate canonicalized form of post request with body' do

    canonicalized_request = Escher.new.canonicalize 'POST', 'http://host.foo.com/', 'foo=bar', 'Mon, 09 Sep 2011 23:36:00 GMT', {
        'Content-Type' => 'application/x-www-form-urlencoded',
    }, ['content-type']
    expect(canonicalized_request).to eq(
                                         'POST
/

content-type:application/x-www-form-urlencoded
date:Mon, 09 Sep 2011 23:36:00 GMT
host:host.foo.com

content-type;date;host
3ba8907e7a252327488df390ed517c45b96dead033600219bdca7107d1d3f88a')

  end
end

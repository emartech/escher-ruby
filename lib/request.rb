#!/usr/bin/ruby

require 'time'
require 'net/http'
require 'uri'
require 'json'

API_SECRET = 'EXPORT_API_SECRET'
ACCESS_KEY_ID = 'EXPORT_ACCESS_KEY_ID'

HEADER_DATE = 'X-EMS-Date'
HEADER_AUTH = 'X-EMS-Auth'

url = 'http://suite.ett.local/api/v2/internal/128090657/language' # trailing slash is important
uri = URI.parse(url)

http = Net::HTTP.new(uri.host, uri.port)

datetime = Time.now.utc.strftime("%Y%m%dT%H%M%SZ")

def build_auth(credentials, signed_headers, signature)
  auth = "EMS-HMAC-SHA256 "
  auth+= [
    "Credential=" + credentials,
    "SignedHeaders=" + signed_headers,
    "Signature=" + signature
  ].join(", ")
end

def build_auth_credential(access_key_id, datetime, region, service_name, request_type)
  auth_credential = [
    access_key_id,
    datetime[0,8],
    region,
    service_name,
    request_type,
  ].join("/")
end

def build_auth_signed_headers headers
  to_sign = headers.keys.map{|k| k.to_s.downcase }
  to_sign.delete(HEADER_AUTH)
  to_sign.sort.join(";")
end

headers = {
  #'host' => 'suite.ett.local',
  'content-type' => "application/json",
  HEADER_DATE => datetime,
}

signed_headers = build_auth_signed_headers(headers)
signature = "0123456789012345678901234567890123456789012345678901234567890123"

credentials = build_auth_credential(ACCESS_KEY_ID, datetime, 'eu', 'suite', 'ems_request')
authorization = build_auth(credentials, signed_headers, signature)

headers[HEADER_AUTH] = authorization
path = uri.path.empty? ? "/" : uri.path

response = http.get(path, headers)
response_json = JSON.parse(response.body)
puts JSON.pretty_generate(response_json)

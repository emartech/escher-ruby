module Escher::Request::DCI::RackEnv

  CUSTOM_HTTP_HEADER_MATCHER = /^HTTP_/
  CONSTANT_HTTP_HEADER_KEYS = %w[CONTENT_LENGTH CONTENT_TYPE]

  protected

  def get_headers_by_rack_env(env)
    format_headers(get_custom_http_headers(env) + get_constant_http_headers(env))
  end

  private

  def get_custom_http_headers(env)
    env.select { |env_str_key, _| env_str_key =~ CUSTOM_HTTP_HEADER_MATCHER }.to_a
  end

  def get_constant_http_headers(env)
    CONSTANT_HTTP_HEADER_KEYS.map { |env_key| [env_key.downcase, env[env_key]] }.select { |k, v| !v.nil? }
  end

  def format_headers(array)
    array.map { |header_name, value| [header_name.sub(CUSTOM_HTTP_HEADER_MATCHER, '').tr('_', '-'), value] }
  end


end
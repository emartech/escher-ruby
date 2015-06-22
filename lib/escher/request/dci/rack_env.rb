module Escher::Request::DCI::RackEnv

  protected

  def get_content_headers(env)
    %w[CONTENT_LENGTH CONTENT_TYPE].map{|env_key| [env_key, env[env_key]] }.select{|k,v| !v.nil? }
  end

end
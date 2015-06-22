module Escher::Request

  require 'escher/request/dci'

  require 'escher/request/base'
  require 'escher/request/hash_request'
  require 'escher/request/rack_request'
  require 'escher/request/legacy_request'
  require 'escher/request/action_dispatch_request'

  require 'escher/request/factory'

end
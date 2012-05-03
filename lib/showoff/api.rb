module Showoff

  ## This helper method is used below and in `showoff.rb`
  def self.parse_uri(uri)
    u = (uri.is_a? URI) ? URI.new(uri) : URI.parse(uri)

    if u.scheme.nil? && u.host.nil?
      unless u.path.nil?
        u.scheme = 'https'
        u.host = u.path
        u.path = ''
      end
    end

    u
  end

  class API

    def initialize(uri='https://showoff.io/')
      @uri = Showoff::Settings.server || uri
    end

    def builder(opt={})
      u = Showoff.parse_uri @uri

      if opt[:path]
        u.path = '/api/' + opt[:path]
      end

      if opt[:user]
        u.user = opt[:user]
        if opt[:password]
          u.password = opt[:password]
        end
      end

      u
    end

    def add_key(k)
      u = self.builder(:path => 'keys/add_anonymous')

      begin
        result = JSON.parse(RestClient.post(u.to_s, :public_key => k.strip))
      rescue
        result = { 'status' => 'error' }
      end

      result
    end

    def generate_key()
      u = self.builder(:path => 'keys/generate')

      begin
        result = JSON.parse(RestClient.get(u.to_s))
      rescue
        result = { 'status' => 'error', 'message' => 'request failed' }
      end

      result
    end

  end
end

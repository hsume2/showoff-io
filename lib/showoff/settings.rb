module Showoff
  class Settings
    class << self

      @@PATH = File.join(ENV['HOME'], '.showoffrc')
      @@CACHE = nil
      @@SERVER = 'https://showoff.io/'

      ## API Settings ##

      def server()
        @@SERVER
      end

      def uri()
        Showoff.parse_uri(@@SERVER)
      end

      def host()
       uri().host
      end

      def scheme()
        uri().scheme
      end

      ## Key Settings ##

      def has_key_file?()
        get('key').is_a?(String)
      end

      def has_key_data?()
        key = get('key')
        return !(key.nil? || key.is_a?(String))
      end

      def private_key_file()
        return get('key') if has_key_file?
      end

      def public_key_data()
        return get('key')['public'] if has_key_data?
      end

      def private_key_data()
        ## Key pair format: { public: '..', private: '...' }
        return get('key')['private'] if has_key_data?
      end

      ## General Access ##

      def get(name)
        load if @@CACHE.nil?
        return @@CACHE[name]
      end

      def set(name, value)
        load if @@CACHE.nil?
        @@CACHE[name] = value
        begin
          JSON.dump(@@CACHE, File.open(@@PATH, 'w'))
        rescue
          puts "Config: failed to update #{@@PATH}"
          exit 1
        end
      end

      def load()
        begin
          config = @@CACHE = JSON.parse(File.read(@@PATH))
        rescue
          config = @@CACHE = {}
        end

        @@SERVER = config['server'] || config['domain'] || @@SERVER
      end
    end
  end
end

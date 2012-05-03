module Showoff
  class Setup
    extend Showoff::Helpers
    class << self

      def windows?
        Config::CONFIG['host_os'] =~ /mswin|mingw/
      end

      def prepare(key=nil)
        ## First, we'll try to make an SSH connection to Showoff.
        begin
          return Showoff::Setup.start key
        rescue Net::SSH::AuthenticationFailed
          setup_auth key
        end

        ## The original connection attempt failed, but a key was
        ## uploaded. Try connecting again. If it fails this time,
        ## quit.
        begin
          return Showoff::Setup.start key
        rescue Net::SSH::AuthenticationFailed
          puts "Cannot start tunnel: auth failed. If this problem persists, contact support@showoff.io"
          exit
        end
      end

      def start(key=nil)
        key = key || Showoff::Settings.private_key_file

        if key
          ## A filename was given or is configured. Use it.
          keys, data, only = [key], nil, true
        elsif Showoff::Settings.has_key_data?
          ## A key pair is stored in the config.
          keys, data, only = nil, [Showoff::Settings.private_key_data], true
        else
          ## No key was given, nothing is configured. Fall back to
          ## whatever happens to be in ~/.ssh
          keys, data, only = nil, nil, false
        end

        host = Showoff::Settings.host
        Net::SSH.start(host, 'showoff', :keys => keys, :keys_only => only, :key_data => data)
      end

      def setup_auth(key=nil)
        key = key || Showoff::Settings.private_key_file
        if key
          result = Showoff::Setup.upload_key "#{key}.pub"
        elsif Showoff::Settings.has_key_data?
          result = Showoff::Setup.resend_key
        else
          result = Showoff::Setup.generate_key
        end

        if !result
          puts "Key setup failed. If this persists, let us know at support@showoff.io."
          exit 1
        end
      end

      def generate_key()
        puts welcome_message

        api = Showoff::API.new

        puts "Generating key..."
        result = api.generate_key
        if result['status'] != 'ok'
          message = result['message'] || 'server error'
          puts "Key generation error: #{message}"
          exit 1
        end

        puts "Saving key..."
        key = result['data']
        Showoff::Settings.set('key', key)
        result = Showoff::Setup.upload_key_body key['public']

        puts "" if result
        return result
      end

      def resend_key()
        puts "Saving key..."
        pubkey = Showoff::Settings.public_key_data
        result = Showoff::Setup.upload_key_body pubkey

        puts "" if result
        return result
      end

      def upload_key(keyfile)
        keyfile = File.expand_path keyfile
        if File.exists? keyfile
          begin
            return upload_key_body(File.read(keyfile))
          rescue
            puts "Upload failed: could not read '#{keyfile}'."
            return false
          end
        else
          puts "Upload failed: '#{keyfile}' does not exist."
          return false
        end
      end

      def upload_key_body(body)
        api = Showoff::API.new
        result = api.add_key body.strip
        if result['status'] != 'error'
          return true
        else
          message = result['message'] || 'server error'
          puts "Upload failed: #{message} (#{keyfile})."
          return false
        end
      end
    end
  end
end

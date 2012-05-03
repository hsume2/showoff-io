require 'json'
require 'showoff/version'

module Showoff
  class Session

    attr_reader :session
    attr_reader :channel
    attr_reader :status
    attr_reader :provided_key
    attr_reader :log_buffer

    def initialize(key=nil)
      if key
        @provided_key = key
      end
      open_session
    end

    def close
      @session.shutdown! # We're going to kill it regardless.
    end

    # Prepares us a Net::SSH session if one isn't open (or it is closed)
    def open_session
      if @session == nil || @session.closed?
        @status = :normal
        @session = Showoff::Setup.prepare(@provided_key)
        @channel = @session.open_channel do |channel|
          channel.exec("api -v #{Showoff::VERSION}") do |ch, success|
            unless success
              puts "\nShowoff is currently experiencing difficulties. If this persists, let us know at support@showoff.io"
              Process.exit
            end
            @dormant = true
            ch.on_eof do |ch|
              if @status == :executing
                puts "\nShowoff was unable to process your request. If this persists, let us know at support@showoff.io"
                Process.exit
              elsif @status != :normal && @status != :closing
                puts "\nShowoff has encountered an error and needs to close. If this persists, let us know at support@showoff.io"
                Process.exit
              else
                print "\n"
                Process.exit
              end
            end
          end

          channel.on_close do |channel|
            print "\n"
            Process.exit
          end
        end
      end
    end

    #def reload_session
    #  @status = :relaoding
    #  execute_command :command => :exit
    #  #@session.shutdown!
    #  #open_session
    #end

    def execute_command(command)
      result = nil
      dormant = false

      cmd = command.to_json
      @channel.send_data cmd

      @status = :executing unless command[:command] == :deallocate # deallocate/close is fire and forget

      @channel.on_data do |ch, data|
        begin
          result = JSON.parse data
        rescue
          result = {'status' => 'error', 'message' => "couldn't parse results"}
        end

        if result['type'] == 'notify'
          notify result
        else
          dormant = true
          @status = :normal
        end
      end

      trap(:INT) {
        @status = :normal
        print "\n"
        exit
      }

      @session.loop {not dormant}
      return result
    end

    # Once we get into showoff mode, things will heppen a little differently.
    # We'll set up the forward and allow the SSH session to loop it indefinitely.
    # This way, we can openly recieve API data from the server as we go.
    def showoff(rhost, rport, lport=80, host='localhost')
      @session.forward.remote lport, host, rport

      @channel.on_data do |ch, data|
        @log_buffer = data
        receive_message data
      end

      @int_pressed = false
      trap(:INT) {
        @int_pressed = true
        @status = :normal
        # We're always going to try to send this, but the server will automatically
        # attempt to detect when something dies and cleanup.
        execute_command :command => :deallocate, :host => rhost
        print "\n"
        exit
      }

      @session.loop { not @int_pressed }
    end

    def receive_message(data)
      # holding this in here because
      # once close is called the lifecycle of
      # the SSH server is not really known
      begin
        result = JSON.parse data
        # We can get lots of messages through the pipe
        # So we need to figure out what we're displaying
        # and why we're doing it.
        case result['status']
        when 'ok'
          @log_buffer = nil
          puts result["message"]
        when 'closing'
          @status = :closing
          if result['reason']
            puts "\nConnection closed: #{result['reason']}"
          elif (result['subscription_type'] == 'pay-as-you-go') && (result['tokens'] != nil && result['tokens'] > 0)
            puts "\nShowoff has disconnected, but you have credits left. Run Showoff to try again."
          elsif result['subscription_type'] == 'pay-as-you-go'
            puts "\nYou ran out of credits. Visit to https://showoff.io/ to reload and get back to sharing."
          elsif result['subscription_type'] == 'trial'
            puts "\nYour 5 minute Showoff Trial is up. Visit https://showoff.io/ to sign up and share longer."
          else
            puts "\nShowoff encountered a problem and needs to disconnect. If this persists, let us know at support@showoff.io"
          end
          @log_buffer = nil
        else
          if result['type'] == 'notify'
            notify result
          end
        end
      rescue
        # These message can be anything, so it might be best
        # to silently ignore items that aren't proper messages.
        # Like this.
      end
    end

    # The server pushed a notification, display it.
    def notify(message)
      puts message['data']
    end

  end
end

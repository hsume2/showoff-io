module Showoff
  class Client
    include Showoff::Helpers

    attr_accessor :session

    def initialize(argv)
      # We're going to parse arguments here rather than in the
      # runner from now on.
      @arguments = argv

      banner = <<-BANNER
      Usage: show [options] <port>
             show [options] <host>
             show [options] <host:port>

      Description:

        Share a server running on localhost:port over the web by tunneling
        through Showoff. A URL is created for each tunnel.

      Simple example:

        # You are developing a Rails site.

        > rails server &
        > show 3000

      Virtual Host example:

        # You are already running something on port 80 that uses
        # virtual host names.

        > show mysite.dev

      BANNER

      @opts = OptionParser.new do |opts|
        opts.banner = banner.gsub(/^ {6}/, '')

        opts.separator ''
        opts.separator 'Options:'

        opts.on('-b', '--basic [USER:PASS]', 'Protect this tunnel with HTTP Basic Auth.') do |basic|
          if basic !~ /^[^\s:]+:[^\s:]+$/
            puts "Basic Auth: bad format, expecting USER:PASS."
            exit 1
          end
          @basic = basic
        end

        opts.on('-c', '--cname [NAME]', 'Allow access to this tunnel as NAME.') do |cname|
          @cname = cname
        end

        opts.on( '-h', '--help', 'Display this help.' ) do
          puts opts
          exit
        end

        opts.on('-i', '--identity [FILE]', 'Use the specified keyfile to connect.') do |keyfile|
          @provided_key = keyfile.chomp(File.extname(keyfile))
        end

        opts.on('-q', '--quiet', 'Suppress additional messages and display only the active Showoff URL.') do
          @quiet = true
        end

        opts.on('-r', '--random', 'Assign a random URL instead of using the hostname.') do
          @random = true
        end

        opts.on('-s', '--secure', 'Always use SSL.') do
          @secure = true
        end

        opts.on('--clear', 'Clear active sessions.') do
          @clear = true
        end

        opts.on('--logout', 'Log out of your account.') do
          @logout = true
        end

        opts.on('--switch', 'Switch to a different account.') do
          @switch = true
        end

        opts.on('--host [HOST]', 'Deprecated, use `show host`') do |host|
          @host = host
        end

      end

      @opts.parse!

      proxy = @arguments[0]
      if proxy.nil? || !parse_host(proxy)
        puts @opts
        exit
      end

    end

    def parse_host(proxy)
      parts = proxy.split ':'

      if parts.length > 3
        return false
      elsif parts.length == 2
        @host = parts[0] if @host.nil?
        @port = parts[1]
        return false if @port.to_i == 0
      elsif parts[0].to_i == 0
        @host = parts[0] if @host.nil?
        @port = 80
      else
        @host = nil
        @port = parts[0]
      end

      return true
    end

    # SSH API Commands
    #  At some point, it would likely be nice to extract
    #  these to their own class.

    def authenticated?
      results = @session.execute_command :command => 'authenticated'
      return results['data']['authenticated']
    end

    def authenticate(email, pass)
      results = @session.execute_command :command => 'authenticate', :email => email, :password => pass
      return results
    end

    def deauthenticate()
      results = @session.execute_command :command => 'deauthenticate'
      return results
    end

    def showoff(port, host='localhost')
      # Allocation message contains URL
      # Consumption message contains trial status, etc

      if @cname && @secure
        puts "WARNING: using `secure` with a CNAME may result in browser warnings." unless @quiet
      end

      # Note: intentional use of `@host` here instead of `host`. The
      # server will do some hostname mangling if an expicit hostname
      # was given.
      begin
        all = @session.execute_command :command => 'allocate', :random => @random, :host => @host, :cname => @cname, :secure => @secure, :basic => @basic, :clear => @clear

        if all['status'] == 'error'
          puts (all['message'] || 'Allocate failed: server error. If this problem persists, contact support@showoff.io.')
          exit 1
        elsif !@clear && all['status'] == 'session-exists'
          active = all['host']
          if ask "A #{active} session is already active. Replace it?"
            @clear = true;
            all = nil
          end
        end

     end while all.nil?

      # The session is allocated, consume it.
      con = @session.execute_command :command => :consume, :port => all['port']

      if con['status'] == 'ok'
        unless @quiet
          puts status_message(all)
        end

        url = show_url(all['url'])
        puts @quiet ? url : "\nShare this URL: #{url}"

        begin
          @session.showoff all['url'], all['port'], port, host
        rescue
          puts "Unable to connect to the local port #{port}.\nMake sure a service is running on this port and try Showoff again."
          exit
        end
      else
        puts "Unable to setup your Showoff tunnel. If this issue persists, let us know at support@showoff.io."
        Process.exit
      end
    end

    def show_url(domain)
      ## Show the public URL. Goals:
      ##
      ## 1. If @quiet, show only a single URL
      ## 2. If @cname, use it as the main URL; use http unless explicit @secure
      ## 3. Otherwise, use Config.scheme by default.
      ##
      scheme = Showoff::Settings.scheme
      url = @secure ? "https://#{domain}/" : "#{scheme}://#{domain}/"
      if @cname
        scheme = @secure ? 'https' : 'http'
        cnamed = "#{scheme}://#{@cname}/"
        url = @quiet ? cnamed : "#{bold(cnamed)} (#{url})"
      elsif !@quiet
        url = bold(url)
      end
    end

    def bold(message)
      if Showoff::Setup.windows?
        message
      else
        "\e[1m#{message}\e[0m"
        end
    end

    def status_message(data)
      "Connected to Showoff." if data['timeout'] == nil
      if data['type'] == 'trial'
        "Connected using 5 minute trial."
      elsif data['type'] == 'pay-as-you-go'
        # we're going to get the situation based on the timeout,
        # rather than a massive refactor of the proxy server
        if data['timeout'] == 86400000
          "Connected with a new credit. Your credit expires in #{time_string data['timeout']}; you have #{data['tokens']} left."
        elsif data['timeout'] == 300000 && data['tokens'] <= 0
          "You're out of credits: connected using the 5 minute trial. \nBuy credits at https://showoff.io/"
        else
          "Connected with a credit. This credit expires in #{time_string data['timeout']}; you have #{data['tokens']} left."
        end
      elsif data['type'] == 'unlimited'
        "Connected, you have unlimited access."
      else
        "Connected to Showoff."
      end
    end

    def time_string(usecs)
      hours = usecs / 1000 / 60 / 60
      minutes = usecs / 1000 / 60 % 60
      seconds = usecs / 1000 % 60 % 60
      hour_text = case hours
      when 0
        ""
      when 1
        "1 hour"
      else
        "#{hours} hours "
      end
      minute_text = case minutes
      when 0
        ""
      when 1
        "1 minute"
      else
        "#{minutes} minutes"
      end
      "#{hour_text}#{minute_text}"
    end

    def add_account
      if ask 'Do you have a Showoff account?', false
        authorize
      end
    end

    def logout
      if !authenticated?
        puts "You're logged out."
      elsif !deauthorize("Logging out")
        exit 1
      end
    end

    def switch_account
      if authenticated?
        ok = deauthorize "Switching accounts: verify your existing account."
        ok = ok && authorize("\nSwitching accounts: verify your new account.")
      else
        ok = authorize "Authorizing: verify your acccount information."
      end

      if !ok
        exit 1
      end
    end

    def account_prompt(message=nil)
      if message
        puts message
      end

      email = prompt 'Enter your email address'
      password = prompt 'Enter your password', false

      return email, password
    end

    def authorize(message=nil)
      email, password = account_prompt message
      res = authenticate email, password

      unless res['status'] == 'ok'
        puts "Authorization failed: #{res['message']}"
        return false
      end

      return true
    end

    def deauthorize(message=nil)
      res = deauthenticate

      unless res['status'] == 'ok'
        puts "Deauthorization failed: #{res['message']}"
        return false
      end

      return true
    end

    # The main action method.
    def runner
      begin
        @session = Showoff::Session.new(@provided_key)

        if @logout
          logout
        elsif @switch
          switch_account
        elsif !authenticated?
          add_account
        end

        showoff @port, @host
      rescue
        # Any other errors that bubble this far don't need
        # to be seen by the user.
        puts "An error has occurred. If this persists, let us know at support@showoff.io."
        puts $!
        exit
      end
    end

  end
end

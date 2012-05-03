module Showoff
  module Helpers
    # Asks a yes/no question. Returns true/false
    def ask(question, default=true)
      option_string = default ? '[Y/n]' : '[y/N]'
      response = nil
      while (response != 'Y') && (response != 'N') && (response != "\r")
        print "#{question} #{option_string} "
        response = HighLine::SystemExtensions.get_character.chr
        puts response
        response.upcase!
      end
      return default if response == "\r"
      return (response == 'Y') ? true : false
    end

    def prompt(question, echo=true)
      print "#{question} > "
      system "stty -echo" unless echo
      response = $stdin.gets.strip
      system "stty echo" unless echo
      while response.empty?
        print "#{question} or use 'q' to quit > "
        system "stty -echo" unless echo
        response = $stdin.gets.strip
        system "stty echo" unless echo
      end
      exit if response.upcase == 'Q'
      print "\n" unless echo
      return response
    end

    def welcome_message
      return <<-WELCOME
Welcome to Showoff

Showoff shares localhost over the web. Before you can use Showoff,
your computer needs to be configured. If you already have a Showoff
account, log in when prompted. Otherwise, try Showoff for free 5
minutes at a time.

      WELCOME
    end

    def no_key_message
      return <<-NO_KEY

No public keys were found. Please refer to the Showoff FAQ[1]
for help generating a key. If you do already have a key, use
'show -i /path/to/key port' to choose it.

[1]: https://showoff.io/support#faq
      NO_KEY
    end

  end
end

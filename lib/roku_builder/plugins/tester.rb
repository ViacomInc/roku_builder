# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Method for running unit tests
  # This is intended to be used with the brstest librbary but should work
  # with other testing libraries
  class Tester < Util
    extend Plugin

    def self.commands
      {test: {device: true, source: true, stage: true}}
    end

    def self.parse_options(parser:, options:)
      parser.separator "Commands:"
      parser.on("-t", "--test", "Test an app") do
        options[:test] = true
      end
    end

    def self.dependencies
      [Loader, Linker]
    end

    # Initialize starting and ending regular expressions
    def init()
      @end_reg = /\*+\s*End testing\s*\*+/
      @start_reg = /\*+\s*Start testing\s*\*+/
      @test_logger = ::Logger.new(STDOUT)
      @test_logger.formatter = proc {|_severity, _datetime, _progname, msg|
        "%s\n\r" % [msg]
      }
      @in_tests = false
      @logs = []
    end

    # Run tests and report results
    # @param sideload_config [Hash] The config for sideloading the app
    def test(options:)
      loader = Loader.new(config: @config)
      loader.sideload(options: options)
      linker = Linker.new(config: @config)
      linker.deeplink(options: Options.new(options: {deeplink: "RunTests:true"}))

      telnet_config ={
        'Host' => @roku_ip_address,
        'Port' => 8085
      }
      connection = Net::Telnet.new(telnet_config)
      connection.waitfor(@end_reg) do |txt|
        handle_text(txt: txt)
      end
      print_logs
      connection.puts("cont\n")
    end

    private

    # Handel testing text
    # @param txt [String] current text from telnet
    # @param in_tests [Boolean] currently parsing test text
    # @return [Boolean] currently parsing test text
    def handle_text(txt:)
      check_for_used_connection(txt: txt)
      txt.split("\n").each do |line|
        check_for_end(line: line)
        @logs.push line if @in_tests
        check_for_start(line: line)
      end
    end

    def check_for_used_connection(txt:)
      if txt =~ /connection already in use/
        raise IOError, "Telnet Connection Already in Use"
      end
    end

    def check_for_end(line:)
      if line =~ @end_reg
        @in_tests = false
        breakline = line.gsub(/./, '*')
        @logs.push line
        @logs.push breakline
        @logs.push breakline
      end
    end

    def check_for_start(line:)
      if line =~ @start_reg
        @logs = []
        @in_tests = true
        breakline = line.gsub(/./, '*')
        @logs.push breakline
        @logs.push breakline
        @logs.push line
      end
    end

    def print_logs
      @logs.each do |log|
        @test_logger.unknown log
      end
    end
  end
  RokuBuilder.register_plugin(Tester)
end

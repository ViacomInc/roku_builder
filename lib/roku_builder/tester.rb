# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Method for running unit tests
  # This is intended to be used with the brstest librbary but should work
  # with other testing libraries
  class Tester < Util

    # Initialize starting and ending regular expressions
    def init()
      @end_reg = /\*\*\*\*\* ENDING TESTS \*\*\*\*\*/
      @start_reg = /\*\*\*\*\* STARTING TESTS \*\*\*\*\*/
    end

    # Run tests and report results
    # @param sideload_config [Hash] The config for sideloading the app
    def run_tests(sideload_config:)
      telnet_config ={
        'Host' => @roku_ip_address,
        'Port' => 8085
      }

      loader = Loader.new(**@device_config)
      connection = Net::Telnet.new(telnet_config)
      code, _build_version = loader.sideload(**sideload_config)

      if code = SUCCESS
        in_tests = false
        connection.waitfor(@end_reg) do |txt|
          in_tests = handle_text(txt: txt, in_tests: in_tests)
        end
        connection.puts("cont\n")
      end
    end

    private

    # Handel testing text
    # @param txt [String] current text from telnet
    # @param in_tests [Boolean] currently parsing test text
    # @return [Boolean] currently parsing test text
    def handle_text(txt:, in_tests:)
      txt.split("\n").each do |line|
        in_tests = false if line =~ @end_reg
        @logger.unknown line if in_tests
        in_tests = true if line =~ @start_reg
      end
      in_tests
    end
  end
end

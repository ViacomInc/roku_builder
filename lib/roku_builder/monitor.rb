# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Monitor development Logs
  class Monitor < Util

    # Initialize port config
    def init()
      @ports = {
        main: 8085,
        sg: 8089,
        task1: 8090,
        task2: 8091,
        task3: 8092,
        taskX: 8093,
      }
    end

    # Monitor a development log on the Roku device
    # @param type [Symbol] The log type to monitor
    def monitor(type:)
      telnet_config = {
        'Host' => @roku_ip_address,
        'Port' => @ports[type]
      }
      waitfor_config = {
        'Match' => /./,
        'Timeout' => false
      }

      thread = Thread.new(telnet_config, waitfor_config) {|telnet,waitfor|
        @logger.info "Monitoring #{type} console(#{telnet['Port']}) on #{telnet['Host'] }"
        connection = Net::Telnet.new(telnet)
        Thread.current[:connection] = connection
        all_text = ""
        while true
          connection.waitfor(waitfor) do |txt|
            all_text = manage_text(all_text: all_text, txt: txt)
          end
        end
      }
      running = true
      while running
        begin
          @logger.info "Q to exit"
          command = gets.chomp
          if command == "q"
            thread.exit
            running = false
          else
            thread[:connection].puts(command)
          end
        rescue SystemExit, Interrupt
          thread[:connection].puts("\C-c")
        end
      end
    end

    private

    # Handel text from telnet
    #  @param all_text [String] remaining partial line text
    #  @param txt [String] current string from telnet
    #  @return [String] remaining partial line text
    def manage_text(all_text:, txt:)
      all_text += txt
      while line = all_text.slice!(/^.*\n/) do
        puts line
      end
      if all_text == "BrightScript Debugger> "
        print all_text
        all_text = ""
      end
      all_text
    end
  end
end

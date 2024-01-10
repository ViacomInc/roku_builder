# ********** Copyright Viacom, Inc. Apache 2.0 **********

module RokuBuilder

  # Monitor development Logs
  class Monitor < Util
    extend Plugin

    def self.commands
      { monitor: {device: true}}
    end

    def self.parse_options(parser:, options:)
      parser.separator "Commands:"
      parser.on("-m", "--monitor [TYPE]", "Run telnet to monitor roku log") do |m|
        options[:monitor] = m || "main"
      end
      parser.separator "Options:"
      parser.on("-R", "--regexp REGEXP", "A regular expression used to filter monitor logs") do |r|
        options[:regexp] = r
      end
    end

    # Initialize port config
    def init()
      @ports = {
        main: 8085,
        profiler: 8080,
      }
      @show_prompt = false
    end

    # Monitor a development log on the Roku device
    def monitor(options:)
      get_device(no_lock: true) do |device|
        if !options[:logfile].nil?
          if options[:logfile].match("config")
            options[:logfile] = @config.console_log
          end
          if options[:clearfile]
            if !options[:logfile].nil?
              File.delete(options[:logfile]) if File.exist?(options[:logfile])
            else
              @logger.unknown "Cannot clear, console_log file not set."
            end
          end
        end
        if options[:logging]
          if !options[:logfile].nil?
            @logger.unknown "Logging to: " + options[:logfile]
          else
            @logger.unknown "Cannot log, console_log file not set."
            options[:logging] = false
          end
        end
        type = options[:monitor].to_sym
        telnet_config = { 'Host' => device.ip, 'Port' => @ports[type] }
        waitfor_config = { 'Match' => /./, 'Timeout' => false }

        thread = Thread.new(telnet_config, waitfor_config) {|telnet,waitfor|
          @logger.info "Monitoring #{type} console(#{telnet['Port']}) on #{telnet['Host'] }"
          connection = Net::Telnet.new(telnet)
          Thread.current[:connection] = connection
          all_text = ""
          while true
            connection.waitfor(waitfor) do |txt|
              all_text = manage_text(all_text: all_text, txt: txt, regexp: options[:regexp], logging: options[:logging], logfile: options[:logfile])
            end
          end
        }
        thread.abort_on_exception = true

        init_readline()

        run_prompt(thread: thread)
      end
    end

    private

    # Setup tab completeion for Readline
    def init_readline
      libedit = false
      begin
        Readline.vi_editing_mode
      rescue NotImplementedError
        libedit = true
      end

      commands = [
        "bsc", "bscs", "brkd", "bt", "c", "classes", "cont", "cont", "down", "d",
        "exit", "gc", "help", "l", "last", "list", "n", "next", "o", "print",
        "p", "?", "s", "stats", "step", "t", "th", "thread", "threads", "ths",
        "over", "out", "up", "u", "q", "v", "var"
      ].sort
      commands.collect { |i| i + ' '  } if libedit

      comp = proc { |s| commands.grep( /^#{Regexp.escape(s)}/  )  }

      Readline.completion_append_character = " "
      Readline.completion_proc = comp
    end

    # Check if needs to display prompt, displays prompt, and processes input
    def run_prompt(thread:)
      running = true
      @logger.unknown "Q to exit"
      while running
        begin
          if @show_prompt
            prompt = 'BrightScript Debugger> '
          else
            prompt = ''
          end
          command = Readline.readline(prompt, true)
          if command =~ /^\s*$/ or Readline::HISTORY.to_a[-2] == command
            Readline::HISTORY.pop
          end
          case command
          when "q"
            thread.exit
            running = false
          else
            thread[:connection].puts(command)
            sleep(0.1)
          end
        rescue SystemExit, Interrupt
          thread[:connection].puts("\C-c")
        end
      end
    end

    # Handle text from telnet
    #  @param all_text [String] remaining partial line text
    #  @param txt [String] current string from telnet
    #  @param regexp [Regexp] regular expression to filter text on
    #  @return [String] remaining partial line text
    def manage_text(all_text:, txt:, regexp: nil, logging: false, logfile: nil)
      raise ExecutionError, "Connection Closed" unless txt
      if /connection is already in use/ =~ txt
        raise ExecutionError, "Connection is in use"
      end
      all_text += txt
      while line = all_text.slice!(/^.*\n/) do
        if !line.strip.empty?
          puts line if regexp.nil? or line.match(regexp)
          if logging
            open(logfile, 'a') do |f|
              f.puts line
            end
          end
        end
      end

      if all_text.downcase == "BrightScript Debugger> ".downcase
        @show_prompt = true
        all_text = ""
      else
        @show_prompt = false
      end
      all_text
    end
  end
  RokuBuilder.register_plugin(Monitor)
end
